#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_DIR="${KILL_LIFE_CAD_AI_BASE_DIR:-$ROOT_DIR/.runtime-home/cad-ai-native-forks}"
KICAD_UPSTREAM="KiCad/KiCad"
FREECAD_UPSTREAM="FreeCAD/FreeCAD"
TARGET_OWNER="${KILL_LIFE_FORK_OWNER:-electron-rare}"
TARGET_BRANCH="${KILL_LIFE_FORK_BRANCH:-kill-life-ai-native}"
CREATE_REMOTE_FORKS=0
DRY_RUN=0
FORCE=0
PROJECTS="kicad freecad"

usage() {
  cat <<'EOF'
Usage: tools/cad/ai_native_forks.sh [options]

Prépare des forks locaux KiCad/FreeCAD pour le lane IA-native Kill_LIFE.

Options:
  --owner OWNER            Propriétaire GitHub du fork (défaut: electron-rare)
  --branch BRANCH          Branche locale cible (défaut: kill-life-ai-native)
  --base-dir DIR           Dossier base local (défaut: .runtime-home/cad-ai-native-forks)
  --projects LIST          Projets à traiter, ex: "kicad freecad" (défaut: kicad freecad)
  --create-forks           Crée les forks GitHub via `gh repo fork` si absents
  --dry-run                Affiche les opérations sans écrire
  --force                  Écrase les répertoires existants
  -h, --help               Aide

Env:
  KILL_LIFE_CAD_AI_BASE_DIR   Override du dossier base local
  KILL_LIFE_FORK_OWNER        Override du propriétaire du fork
  KILL_LIFE_FORK_BRANCH       Override de la branche IA-native
EOF
}

log() {
  printf '[kill_life:cad-forks] %s\n' "$*" >&2
}

die() {
  printf '[kill_life:cad-forks][err] %s\n' "$*" >&2
  exit 1
}

ensure_dir() {
  local dir="$1"
  if [ -d "$dir" ] && [ "$FORCE" -eq 1 ]; then
    rm -rf "$dir"
  fi
  mkdir -p "$dir"
}

run_or_dry() {
  local cmd="$*"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "dry-run: $cmd"
    return 0
  fi
  eval "$cmd"
}

gh_auth_check() {
  command -v gh >/dev/null 2>&1 || die "gh CLI requis pour la création de forks"
  if ! gh auth status >/dev/null 2>&1; then
    die "gh CLI non authentifié. Lance `gh auth login` puis relance."
  fi
}

create_fork_target() {
  local upstream_slug="$1"
  local target_repo="$2"

  if gh repo view "$target_repo" >/dev/null 2>&1; then
    log "Fork existant: $target_repo"
    return 0
  fi

  log "Fork manquant: $target_repo"
  if ! gh repo fork "$upstream_slug" --org "$TARGET_OWNER" 2>/tmp/.kill_life_gh_fork_err; then
    if grep -qi "Fork\\.organization is invalid" /tmp/.kill_life_gh_fork_err; then
      log "Target owner is user account; retry without --org"
      if ! gh repo fork "$upstream_slug" 2>/tmp/.kill_life_gh_fork_err; then
        cat /tmp/.kill_life_gh_fork_err >&2
        return 1
      fi
      return 0
    fi
    cat /tmp/.kill_life_gh_fork_err >&2
    return 1
  fi
}

resolve_fork_repo() {
  local upstream_slug="$1"
  local target_owner="$2"
  local target_repo="$3"

  if gh repo view "$target_repo" >/dev/null 2>&1; then
    printf '%s' "$target_repo"
    return 0
  fi

  gh api \
    "repos/$upstream_slug/forks" \
    --paginate \
    --jq ".[] | select(.owner.login == \"$target_owner\") | .full_name" \
  | head -n 1
}

ensure_remote() {
  local dir="$1"
  local name="$2"
  local url="$3"

  if git -C "$dir" remote get-url "$name" >/dev/null 2>&1; then
    run_or_dry "git -C $dir remote set-url $name $url"
    return
  fi
  run_or_dry "git -C $dir remote add $name $url"
}

ensure_remote_if_missing() {
  local dir="$1"
  local name="$2"
  local url="$3"

  if git -C "$dir" remote get-url "$name" >/dev/null 2>&1; then
    return
  fi
  run_or_dry "git -C $dir remote add $name $url"
}

sync_remote_push_url() {
  local dir="$1"
  local name="$2"
  local url="$3"
  run_or_dry "git -C $dir remote set-url --push $name $url"
}

sync_remote_push_url_if_missing() {
  local dir="$1"
  local name="$2"
  local url="$3"

  if git -C "$dir" remote get-url "$name" >/dev/null 2>&1; then
    return
  fi
  run_or_dry "git -C $dir remote set-url --push $name $url"
}

derive_repo_name() {
  local slug="$1"
  printf '%s' "${slug##*/}"
}

derive_repo_remote_url() {
  local owner="$1"
  local slug="$2"
  printf '%s' "https://github.com/$owner/$slug.git"
}

ensure_project_repo() {
  local project="$1"
  local upstream_slug="$2"
  local upstream_url="$3"
  local repo_name
  local target_repo

  repo_name="$(derive_repo_name "$upstream_slug")"
  target_repo="$TARGET_OWNER/$repo_name"
  local target_url
  target_url="$(derive_repo_remote_url "$TARGET_OWNER" "$repo_name")"
  local project_dir="$BASE_DIR/$project-ki"
  local default_branch
  local remote_head
  local source_url
  local resolved_target_repo
  local use_fork=1

  log "=== $project ($upstream_slug) ==="
  ensure_dir "$BASE_DIR"

  if [ "$CREATE_REMOTE_FORKS" -eq 1 ]; then
    gh_auth_check
    create_fork_target "$upstream_slug" "$target_repo" || die "Échec de création/référence du fork $target_repo"
    resolved_target_repo="$(resolve_fork_repo "$upstream_slug" "$TARGET_OWNER" "$target_repo")"
    if [ -z "$resolved_target_repo" ]; then
      die "Impossible de résoudre le nom du fork pour $target_repo"
    fi
    target_repo="$resolved_target_repo"
    target_url="$(derive_repo_remote_url "${resolved_target_repo%/*}" "${resolved_target_repo#*/}")"
    source_url="$target_url"
  else
    source_url="$upstream_url"
    use_fork=0
  fi

  if [ -d "$project_dir/.git" ]; then
    log "Repo existante détectée: $project_dir"
  else
    if [ "$DRY_RUN" -eq 1 ]; then
      log "Création clone prévue: $project_dir <- $source_url"
    else
      if [ "$use_fork" -eq 1 ]; then
        if [ -d "$project_dir" ]; then
          rm -rf "$project_dir"
        fi
      fi
      log "Clone: $source_url"
      run_or_dry "git clone --filter=blob:none --depth=1 $source_url $project_dir"
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ] && [ ! -d "$project_dir/.git" ]; then
    log "skip remotes (dry-run + no local repo yet)"
    return
  fi

  local canonical_origin
  if [ "$use_fork" -eq 1 ]; then
    ensure_remote "$project_dir" origin "$target_url"
    sync_remote_push_url "$project_dir" origin "$target_url"
    ensure_remote "$project_dir" upstream "$upstream_url"
    sync_remote_push_url "$project_dir" upstream "$upstream_url"
  else
    ensure_remote_if_missing "$project_dir" origin "$upstream_url"
    sync_remote_push_url_if_missing "$project_dir" origin "$upstream_url"
    ensure_remote "$project_dir" upstream "$upstream_url"
    sync_remote_push_url "$project_dir" upstream "$upstream_url"
  fi

  remote_head="$(git -C $project_dir remote show origin 2>/dev/null | awk '/HEAD branch:/{print $NF}' | tr -d '[:space:]')"
  default_branch="${remote_head:-main}"
  if [ -z "$default_branch" ] || [ "$default_branch" = "(unknown)" ]; then
    default_branch="main"
  fi

  log "default branch=$default_branch"
  run_or_dry "git -C $project_dir fetch --all --prune"
  if git -C "$project_dir" show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    run_or_dry "git -C $project_dir switch $TARGET_BRANCH"
  else
      run_or_dry "git -C $project_dir switch -c $TARGET_BRANCH origin/$default_branch"
  fi

  log "Statut $project: $(git -C $project_dir rev-parse --abbrev-ref HEAD) sur $(git -C $project_dir rev-parse --short HEAD)"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --owner)
      [ "$#" -ge 2 ] || die "--owner requires a value"
      TARGET_OWNER="$2"
      shift 2
      ;;
    --branch)
      [ "$#" -ge 2 ] || die "--branch requires a value"
      TARGET_BRANCH="$2"
      shift 2
      ;;
    --base-dir)
      [ "$#" -ge 2 ] || die "--base-dir requires a value"
      BASE_DIR="$2"
      shift 2
      ;;
    --projects)
      [ "$#" -ge 2 ] || die "--projects requires a value"
      PROJECTS="$2"
      shift 2
      ;;
    --create-forks)
      CREATE_REMOTE_FORKS=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      die "Option inconnue: $1"
      ;;
  esac
done

mkdir -p "$BASE_DIR"
manifest_path="$BASE_DIR/manifest.md"
cat >"$manifest_path" <<EOF
# CAD AI-native fork manifest
BASE_DIR=$BASE_DIR
OWNER=$TARGET_OWNER
BRANCH=$TARGET_BRANCH
DRY_RUN=$DRY_RUN
CREATE_REMOTE_FORKS=$CREATE_REMOTE_FORKS
EOF

for project in $PROJECTS; do
  case "$project" in
    kicad)
      ensure_project_repo "$project" "$KICAD_UPSTREAM" "$(derive_repo_remote_url "KiCad" "KiCad")"
      ;;
    freecad)
      ensure_project_repo "$project" "$FREECAD_UPSTREAM" "$(derive_repo_remote_url "FreeCAD" "FreeCAD")"
      ;;
    *)
      die "Projet inconnu: $project"
      ;;
  esac
done

{
  echo "## Remotes"
  for project in $PROJECTS; do
    if [ "$DRY_RUN" -eq 0 ] && [ -d "$BASE_DIR/$project-ki/.git" ]; then
      echo "### $project"
      git -C "$BASE_DIR/$project-ki" remote -v
      echo
    fi
  done
} >>"$manifest_path"

log "Manifest écrit dans $manifest_path"
