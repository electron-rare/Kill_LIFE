# Runtime Home

Ce document fixe la règle pour les launchers locaux `Kill_LIFE` qui exécutent :

- des outils Python
- des outils Node
- des conteneurs Docker remappés avec `--user uid:gid`

## Problème visé

Sans `HOME` explicite, certains runtimes essaient d’utiliser un home implicite comme `/home/<user>`.

En environnement local ou conteneurisé, cela peut produire des erreurs du type :

```text
EACCES: permission denied, mkdir '/home/clems'
```

Le pattern est typique quand :

- le process ne tourne pas en root
- le parent de `HOME` n’est pas writable
- le runtime tente d’écrire un cache, une config ou un état local

## Règle projet

Tout launcher `Kill_LIFE` qui peut écrire localement doit définir explicitement :

- `HOME`
- `XDG_CONFIG_HOME`
- `XDG_CACHE_HOME`

Ces chemins doivent pointer vers un répertoire local au repo, jamais vers `/home/<user>` implicite.

## Emplacements utilisés

Deux familles sont utilisées dans le repo :

- `./.runtime-home/<tool>` pour les wrappers host-side génériques
- `./.cad-home/<tool>` pour les launchers CAD/EDA

Ces dossiers sont ignorés par Git.

## Helper commun

Le helper shell commun est :

- [tools/lib/runtime_home.sh](../tools/lib/runtime_home.sh)

Fonctions exposées :

- `kill_life_runtime_home_init <root_dir> <runtime_name> [base_dir]`
- `kill_life_runtime_home_ensure`

## Exemple minimal

```bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tools/lib/runtime_home.sh"

kill_life_runtime_home_init "$ROOT_DIR" "my-tool"
kill_life_runtime_home_ensure

exec python3 my_tool.py "$@"
```

## Cas Docker remappé

Si un conteneur est lancé avec `--user "$(id -u):$(id -g)"`, il faut aussi propager ces variables :

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e HOME="$HOME" \
  -e XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
  -e XDG_CACHE_HOME="$XDG_CACHE_HOME" \
  image \
  sh -lc 'mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"; exec tool "$@"' sh "$@"
```

## Scripts déjà alignés

- [tools/hw/kicad_cli.sh](../tools/hw/kicad_cli.sh)
- [tools/hw/run_kicad_mcp.sh](../tools/hw/run_kicad_mcp.sh)
- [tools/run_knowledge_base_mcp.sh](../tools/run_knowledge_base_mcp.sh)
- [tools/run_github_dispatch_mcp.sh](../tools/run_github_dispatch_mcp.sh)
- [tools/run_nexar_mcp.sh](../tools/run_nexar_mcp.sh)

## Revue rapide avant merge

Avant d’ajouter un nouveau launcher :

- vérifier s’il peut écrire des caches/configs
- ne pas supposer que `HOME` existe déjà
- ne pas dépendre d’un home hôte implicite
- créer explicitement les dossiers runtime nécessaires
- ajouter le répertoire d’état à `.gitignore` si besoin
