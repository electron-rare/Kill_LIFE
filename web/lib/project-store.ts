import { mkdir, readFile, readdir, stat, writeFile } from "node:fs/promises";
import { dirname, extname, join, posix, relative, resolve, sep } from "node:path";

import { getGitProjectState } from "@/lib/git-project";

type ProjectNode = {
  path: string;
  kind: "directory" | "file";
};

type DiagramRecord = {
  path: string;
  name: string;
  scene: string;
};

type CiRun = {
  id: string;
  pipeline: string;
  status: string;
  queuedAt: string;
};

type ArtifactRecord = {
  id: string;
  label: string;
  kind: string;
  status: string;
  url: string | null;
  sourcePath: string | null;
};

type PullRequestRecord = {
  id: string;
  title: string;
  status: string;
  author: string;
  hasPcbDiff: boolean;
  hasDiagramDiff: boolean;
  hasArtifactPreview: boolean;
  sourceBranch: string;
  targetBranch: string;
  changedFiles: string[];
  artifactIds: string[];
};

const APP_ROOT = process.cwd();
const REPO_ROOT = resolve(APP_ROOT, "..");
const PROJECT_ROOT = join(APP_ROOT, "project");
const DIAGRAMS_ROOT = join(PROJECT_ROOT, "diagrams");
const CI_ROOT = join(PROJECT_ROOT, ".ci");
const REPO_ARTIFACTS_ROOT = join(REPO_ROOT, "artifacts");
const CI_QUEUE_FILE = join(CI_ROOT, "queue.json");
const CI_RUNS_FILE = join(CI_ROOT, "runs.json");
const ARTIFACTS_FILE = join(CI_ROOT, "artifacts.json");

async function ensureProjectLayout() {
  await mkdir(DIAGRAMS_ROOT, { recursive: true });
  await mkdir(CI_ROOT, { recursive: true });

  try {
    await stat(CI_QUEUE_FILE);
  } catch {
    await writeFile(CI_QUEUE_FILE, "[]\n", "utf8");
  }

  try {
    await stat(CI_RUNS_FILE);
  } catch {
    await writeFile(CI_RUNS_FILE, "[]\n", "utf8");
  }

  try {
    await stat(ARTIFACTS_FILE);
  } catch {
    await writeFile(ARTIFACTS_FILE, "[]\n", "utf8");
  }

}

function toPosixPath(filePath: string) {
  return filePath.split(sep).join("/");
}

function normalizeStoredPath(rawPath: string | null) {
  if (!rawPath) {
    return null;
  }

  const absolutePath = resolve(REPO_ROOT, rawPath);

  if (absolutePath.startsWith(REPO_ROOT)) {
    return toPosixPath(relative(REPO_ROOT, absolutePath));
  }

  return rawPath;
}

function normalizeArtifactUrl(rawPath: string | null) {
  if (!rawPath) {
    return null;
  }

  if (
    rawPath.startsWith("/api/") ||
    rawPath.startsWith("http://") ||
    rawPath.startsWith("https://")
  ) {
    return rawPath;
  }

  const absolutePath = resolve(REPO_ROOT, rawPath);

  if (absolutePath.startsWith(PROJECT_ROOT)) {
    return `/api/project-files/${toPosixPath(relative(PROJECT_ROOT, absolutePath))}`;
  }

  if (absolutePath.startsWith(REPO_ARTIFACTS_ROOT)) {
    return `/api/artifacts/${toPosixPath(
      relative(REPO_ARTIFACTS_ROOT, absolutePath)
    )}`;
  }

  return null;
}

async function walkDirectory(
  absoluteDir: string,
  relativeDir = ""
): Promise<ProjectNode[]> {
  const entries = await readdir(absoluteDir, { withFileTypes: true });
  const nodes: ProjectNode[] = [];

  for (const entry of entries.sort((left, right) =>
    left.name.localeCompare(right.name)
  )) {
    const nextAbsolute = join(absoluteDir, entry.name);
    const nextRelative = posix.join(relativeDir, entry.name);

    if (entry.isDirectory()) {
      nodes.push({
        path: nextRelative,
        kind: "directory"
      });
      nodes.push(...(await walkDirectory(nextAbsolute, nextRelative)));
      continue;
    }

    nodes.push({
      path: nextRelative,
      kind: "file"
    });
  }

  return nodes;
}

async function collectDiagramRecords(): Promise<DiagramRecord[]> {
  const nodes = await walkDirectory(DIAGRAMS_ROOT, "diagrams");
  const diagrams = nodes.filter((node) => node.path.endsWith(".excalidraw"));

  return Promise.all(
    diagrams.map(async (diagram) => ({
      path: diagram.path,
      name: diagram.path.split("/").pop() ?? diagram.path,
      scene: await readFile(resolveProjectPath(diagram.path.split("/")), "utf8")
    }))
  );
}

async function loadCiRuns(): Promise<CiRun[]> {
  await ensureProjectLayout();
  const raw = await readFile(CI_RUNS_FILE, "utf8");

  try {
    return JSON.parse(raw) as CiRun[];
  } catch {
    return [];
  }
}

async function writeCiRuns(runs: CiRun[]) {
  await writeFile(CI_RUNS_FILE, JSON.stringify(runs, null, 2), "utf8");
}

async function loadArtifacts(): Promise<ArtifactRecord[]> {
  await ensureProjectLayout();
  const raw = await readFile(ARTIFACTS_FILE, "utf8");

  try {
    const parsed = JSON.parse(raw) as Array<{
      id: string;
      label: string;
      kind: string;
      status: string;
      url: string | null;
      sourcePath?: string | null;
    }>;

    return parsed.map((artifact) => ({
      ...artifact,
      url: normalizeArtifactUrl(artifact.url),
      sourcePath:
        artifact.sourcePath ?? normalizeStoredPath(artifact.url ?? null)
    }));
  } catch {
    return [];
  }
}

async function findFirstProjectFile(extensions: string[]) {
  const nodes = await walkDirectory(PROJECT_ROOT);
  const match = nodes.find((node) =>
    extensions.includes(extname(node.path).toLowerCase())
  );

  if (!match) {
    return null;
  }

  return `/api/project-files/${match.path}`;
}

async function findFirstProjectFilePath(extensions: string[]) {
  const nodes = await walkDirectory(PROJECT_ROOT);
  const match = nodes.find((node) =>
    extensions.includes(extname(node.path).toLowerCase())
  );

  if (!match) {
    return null;
  }

  return resolveProjectPath(match.path.split("/"));
}

export function resolveProjectPath(segments: string[]) {
  const filePath = resolve(PROJECT_ROOT, ...segments);

  if (!filePath.startsWith(PROJECT_ROOT)) {
    throw new Error("path escapes the project root");
  }

  return filePath;
}

export function resolveRepoArtifactPath(segments: string[]) {
  const filePath = resolve(REPO_ARTIFACTS_ROOT, ...segments);

  if (!filePath.startsWith(REPO_ARTIFACTS_ROOT)) {
    throw new Error("path escapes the artifact root");
  }

  return filePath;
}

function buildReviewSummary(
  branch: string | null,
  changedFiles: string[],
  ciRuns: CiRun[],
  artifacts: ArtifactRecord[]
) {
  const latestRun = ciRuns[0]?.status ?? "no-ci-yet";
  const changeLabel =
    changedFiles.length === 0
      ? "working tree clean"
      : `${changedFiles.length} tracked file(s) changed`;

  return `${branch ?? "detached-head"} · ${changeLabel} · latest CI ${latestRun} · ${artifacts.length} artifact(s)`;
}

// ---------------------------------------------------------------------------
// GitHub PR API
// ---------------------------------------------------------------------------

const GITHUB_REPO =
  process.env.GITHUB_REPO ?? "electron-rare/Kill_LIFE";
const GITHUB_API = "https://api.github.com";

async function fetchGitHubPRs(artifacts: ArtifactRecord[]): Promise<PullRequestRecord[] | null> {
  const token = process.env.GITHUB_TOKEN;
  if (!token) return null;

  try {
    const resp = await fetch(`${GITHUB_API}/repos/${GITHUB_REPO}/pulls?state=open&per_page=20`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
      },
      signal: AbortSignal.timeout(5000),
    });
    if (!resp.ok) return null;

    const prs = (await resp.json()) as Array<Record<string, unknown>>;
    const artifactIds = artifacts.map((a) => a.id);

    return prs.map((pr) => {
      const files: string[] = [];
      const title = typeof pr.title === "string" ? pr.title : "";
      const sourceBranch = (pr.head as Record<string, unknown>)?.ref as string ?? "";
      const targetBranch = (pr.base as Record<string, unknown>)?.ref as string ?? "main";
      const author = ((pr.user as Record<string, unknown>)?.login as string) ?? "unknown";
      const state = typeof pr.state === "string" ? pr.state : "open";
      const number = typeof pr.number === "number" ? pr.number : 0;

      return {
        id: String(number),
        title,
        status: state,
        author,
        hasPcbDiff: false,
        hasDiagramDiff: false,
        hasArtifactPreview: artifactIds.length > 0,
        sourceBranch,
        targetBranch,
        changedFiles: files,
        artifactIds,
      } satisfies PullRequestRecord;
    });
  } catch {
    return null;
  }
}

function derivePullRequests(
  branch: string | null,
  head: string | null,
  author: string | null,
  changedFiles: string[],
  ciRuns: CiRun[],
  artifacts: ArtifactRecord[]
): PullRequestRecord[] {
  const latestRun = ciRuns[0]?.status;
  const artifactIds = artifacts.map((artifact) => artifact.id);
  const hasPcbDiff = changedFiles.some(
    (path) => path.endsWith(".kicad_pcb") || path.endsWith(".kicad_sch")
  );
  const hasDiagramDiff = changedFiles.some((path) =>
    path.endsWith(".excalidraw")
  );
  const hasArtifactPreview = artifacts.some((artifact) => Boolean(artifact.url));

  return [
    {
      id: head ?? branch ?? "working-tree",
      title:
        changedFiles.length > 0
          ? `${branch ?? "working-tree"} review`
          : "Working tree clean",
      status:
        changedFiles.length === 0 ? "clean" : latestRun ?? "changes-detected",
      author: author ?? "local-worktree",
      hasPcbDiff,
      hasDiagramDiff,
      hasArtifactPreview,
      sourceBranch: branch ?? "detached-head",
      targetBranch: "main",
      changedFiles,
      artifactIds
    }
  ];
}

export async function getProjectSnapshot() {
  await ensureProjectLayout();

  const [tree, diagrams, boardUrl, schematicUrl, ciRuns, artifacts, gitState] =
    await Promise.all([
      walkDirectory(PROJECT_ROOT),
      collectDiagramRecords(),
      findFirstProjectFile([".kicad_pcb"]),
      findFirstProjectFile([".kicad_sch"]),
      loadCiRuns(),
      loadArtifacts(),
      getGitProjectState(REPO_ROOT, PROJECT_ROOT)
    ]);
  const pullRequests =
    (await fetchGitHubPRs(artifacts)) ??
    derivePullRequests(
      gitState.branch,
      gitState.head,
      gitState.author,
      gitState.changedFiles,
      ciRuns,
      artifacts
    );

  return {
    id: `yiacad-${gitState.branch ?? "local"}`,
    name: "YiACAD Local Workspace",
    rootPath: toPosixPath(relative(REPO_ROOT, PROJECT_ROOT)),
    repoProvider: `github:${GITHUB_REPO}`,
    repoVisibility: "repo-backed working tree",
    repoBranch: gitState.branch,
    repoHead: gitState.head,
    repoAuthor: gitState.author,
    changedFiles: gitState.changedFiles,
    reviewSummary: buildReviewSummary(
      gitState.branch,
      gitState.changedFiles,
      ciRuns,
      artifacts
    ),
    tree,
    diagrams,
    boardUrl,
    schematicUrl,
    ciRuns,
    artifacts,
    pullRequests
  };
}

export async function saveDiagram(relativePath: string, scene: string) {
  await ensureProjectLayout();

  if (!relativePath.startsWith("diagrams/")) {
    throw new Error("diagram path must live under project/diagrams");
  }

  if (!relativePath.endsWith(".excalidraw")) {
    throw new Error("diagram path must end with .excalidraw");
  }

  const absolutePath = resolveProjectPath(relativePath.split("/"));
  await mkdir(dirname(absolutePath), { recursive: true });
  await writeFile(absolutePath, `${scene.trim()}\n`, "utf8");

  return {
    path: relativePath,
    name: relativePath.split("/").pop() ?? relativePath,
    scene: await readFile(absolutePath, "utf8")
  };
}
