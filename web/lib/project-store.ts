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
  engine: string;
  status: string;
  summary: string;
  degradedReasons: string[];
  artifactCount: number;
  queuedAt: string;
  startedAt: string | null;
  completedAt: string | null;
};

type ArtifactRecord = {
  id: string;
  label: string;
  kind: string;
  status: string;
  url: string | null;
  sourcePath: string | null;
  runId: string | null;
  summary: string | null;
};

type GitHubCheckRecord = {
  id: string;
  name: string;
  workflow: string | null;
  status: string;
  conclusion: string | null;
  summary: string;
  detailsUrl: string | null;
  completedAt: string | null;
  headSha: string | null;
  pullRequestId: string | null;
};

type EvidencePackRecord = {
  id: string;
  name: string;
  workflow: string;
  status: string;
  conclusion: string | null;
  summary: string;
  detailsUrl: string | null;
  artifactUrl: string | null;
  artifactNames: string[];
  createdAt: string;
  updatedAt: string;
  headSha: string | null;
  pullRequestId: string | null;
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
  url: string | null;
  updatedAt: string | null;
  headSha: string | null;
  checkSummary: string;
  changeScope: string;
  riskLevel: string;
  mergeRecommendation: string;
  changedFiles: string[];
  artifactIds: string[];
  checkIds: string[];
  evidencePackIds: string[];
};

type GitHubReviewData = {
  pullRequests: PullRequestRecord[];
  githubChecks: GitHubCheckRecord[];
  evidencePacks: EvidencePackRecord[];
};

export type PublishPullRequestSummaryResult = {
  pullRequestId: string;
  commentUrl: string | null;
  action: "created" | "updated";
  summary: string;
};

type PullRequestDiffProfile = {
  scope: "docs-only" | "cad" | "web" | "runtime" | "mixed" | "local-only";
  touchesDocs: boolean;
  touchesCad: boolean;
  touchesWeb: boolean;
  touchesRuntime: boolean;
};

type PullRequestAssessment = {
  riskLevel: "low" | "medium" | "high";
  mergeRecommendation: "favorable" | "caution" | "blocking";
  rationale: string[];
  nextSteps: string[];
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
    const parsed = JSON.parse(raw) as Array<
      Partial<CiRun> & Pick<CiRun, "id" | "pipeline" | "status" | "queuedAt">
    >;
    return parsed.map(normalizeCiRun);
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
      runId?: string | null;
      summary?: string | null;
    }>;

    return parsed.map((artifact) => ({
      ...artifact,
      url: normalizeArtifactUrl(artifact.url),
      sourcePath:
        artifact.sourcePath ?? normalizeStoredPath(artifact.url ?? null),
      runId: artifact.runId ?? null,
      summary: artifact.summary ?? null
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
  artifacts: ArtifactRecord[],
  githubChecks: GitHubCheckRecord[],
  evidencePacks: EvidencePackRecord[]
) {
  const latestRun = ciRuns[0];
  const latestLabel = latestRun
    ? `${latestRun.status}${latestRun.summary ? ` · ${latestRun.summary}` : ""}`
    : "no-ci-yet";
  const changeLabel =
    changedFiles.length === 0
      ? "working tree clean"
      : `${changedFiles.length} tracked file(s) changed`;
  const failedChecks = githubChecks.filter(isFailingGitHubCheck).length;
  const runningChecks = githubChecks.filter(isRunningGitHubCheck).length;
  const checkLabel =
    githubChecks.length === 0
      ? "no-github-checks"
      : failedChecks > 0
        ? `${failedChecks} failed GitHub check(s)`
        : runningChecks > 0
          ? `${runningChecks} GitHub check(s) running`
          : `${githubChecks.length} GitHub check(s) tracked`;
  const evidenceLabel =
    evidencePacks.length === 0
      ? "no-evidence-pack"
      : `${evidencePacks.length} evidence pack(s)`;

  return `${branch ?? "detached-head"} · ${changeLabel} · latest CI ${latestLabel} · ${checkLabel} · ${evidenceLabel} · ${artifacts.length} artifact(s)`;
}

function stringValue(value: unknown) {
  return typeof value === "string" && value.trim() ? value : null;
}

function numberValue(value: unknown) {
  return typeof value === "number" ? value : null;
}

function summarizeText(value: string | null, fallback: string) {
  if (!value) {
    return fallback;
  }

  return value.replace(/\s+/g, " ").trim() || fallback;
}

function isFailingGitHubCheck(check: Pick<GitHubCheckRecord, "status" | "conclusion">) {
  return ["failure", "failed", "cancelled", "timed_out", "action_required"].includes(
    check.conclusion ?? check.status
  );
}

function isRunningGitHubCheck(check: Pick<GitHubCheckRecord, "status">) {
  return ["queued", "requested", "waiting", "pending", "in_progress"].includes(check.status);
}

function isPassingGitHubCheck(check: Pick<GitHubCheckRecord, "status" | "conclusion">) {
  return ["success", "neutral", "skipped", "passed"].includes(check.conclusion ?? check.status);
}

function normalizedCheckStatus(status: string | null, conclusion: string | null) {
  if ((status ?? "").toLowerCase() === "completed") {
    return (conclusion ?? "completed").toLowerCase();
  }

  return (status ?? "queued").toLowerCase();
}

function normalizedRunStatus(status: string | null, conclusion: string | null) {
  if ((status ?? "").toLowerCase() === "completed") {
    return (conclusion ?? "completed").toLowerCase();
  }

  return (status ?? "queued").toLowerCase();
}

function buildCheckSummary(checks: GitHubCheckRecord[]) {
  if (checks.length === 0) {
    return "No GitHub checks loaded.";
  }

  const failed = checks.filter(isFailingGitHubCheck).length;
  const running = checks.filter(isRunningGitHubCheck).length;
  const passed = checks.filter(isPassingGitHubCheck).length;
  const parts: string[] = [];

  if (failed > 0) {
    parts.push(`${failed} failed`);
  }
  if (running > 0) {
    parts.push(`${running} running`);
  }
  if (passed > 0) {
    parts.push(`${passed} passed`);
  }

  return parts.length > 0 ? `${parts.join(" · ")} GitHub checks` : `${checks.length} GitHub checks tracked`;
}

function derivePullRequestStatus(
  fallbackStatus: string,
  checks: GitHubCheckRecord[],
  evidencePacks: EvidencePackRecord[]
) {
  if (checks.some(isFailingGitHubCheck)) {
    return "failed";
  }

  if (checks.some(isRunningGitHubCheck) || evidencePacks.some((pack) => pack.status === "in_progress")) {
    return "running";
  }

  if (checks.length > 0 && checks.every(isPassingGitHubCheck)) {
    return "passed";
  }

  return fallbackStatus;
}

const TRACKED_GITHUB_WORKFLOWS = new Set([
  "YiACAD Product",
  "KiCad Exports",
  "Evidence Pack Validation"
]);
const YIACAD_EVIDENCE_PACK_PREFIX = "yiacad-evidence-pack";
const YIACAD_PR_SUMMARY_MARKER = "<!-- yiacad-pr-summary -->";
const DOC_EXTENSIONS = new Set([".md", ".mdx", ".txt", ".rst"]);
const CAD_EXTENSIONS = new Set([
  ".kicad_pcb",
  ".kicad_sch",
  ".kicad_pro",
  ".fcstd",
  ".step",
  ".stp",
  ".wrl",
  ".kibot.yaml",
  ".kibot.yml"
]);

function isEvidencePackArtifactName(name: string) {
  return (
    name === YIACAD_EVIDENCE_PACK_PREFIX ||
    name.startsWith(`${YIACAD_EVIDENCE_PACK_PREFIX}-`)
  );
}

function changedFileExtension(filePath: string) {
  const lower = filePath.toLowerCase();

  for (const extension of CAD_EXTENSIONS) {
    if (lower.endsWith(extension)) {
      return extension;
    }
  }

  const simpleExtension = extname(lower);
  return simpleExtension || null;
}

function classifyPullRequestDiff(changedFiles: string[]): PullRequestDiffProfile {
  const touchesDocs = changedFiles.some((filePath) => {
    const lower = filePath.toLowerCase();
    const extension = changedFileExtension(lower);
    return (
      lower.startsWith("docs/") ||
      lower.startsWith("specs/") ||
      lower === "readme.md" ||
      extension !== null && DOC_EXTENSIONS.has(extension)
    );
  });
  const touchesCad = changedFiles.some((filePath) => {
    const lower = filePath.toLowerCase();
    const extension = changedFileExtension(lower);
    return (
      lower.startsWith("hardware/") ||
      lower.startsWith("tools/cad/") ||
      lower.startsWith("tools/hw/") ||
      (extension !== null && CAD_EXTENSIONS.has(extension))
    );
  });
  const touchesWeb = changedFiles.some((filePath) =>
    filePath.toLowerCase().startsWith("web/")
  );
  const touchesRuntime = changedFiles.some((filePath) => {
    const lower = filePath.toLowerCase();
    return (
      lower.startsWith(".github/workflows/") ||
      lower.startsWith("tools/ci/") ||
      lower.startsWith("tools/cockpit/")
    );
  });
  const activeDimensions = [touchesDocs, touchesCad, touchesWeb, touchesRuntime].filter(
    Boolean
  ).length;

  let scope: PullRequestDiffProfile["scope"] = "local-only";
  if (activeDimensions === 0) {
    scope = "local-only";
  } else if (touchesDocs && !touchesCad && !touchesWeb && !touchesRuntime) {
    scope = "docs-only";
  } else if (touchesCad && !touchesWeb && !touchesRuntime) {
    scope = "cad";
  } else if (touchesWeb && !touchesCad && !touchesRuntime) {
    scope = "web";
  } else if (touchesRuntime && !touchesCad && !touchesWeb) {
    scope = "runtime";
  } else {
    scope = "mixed";
  }

  return {
    scope,
    touchesDocs,
    touchesCad,
    touchesWeb,
    touchesRuntime
  };
}

function assessPullRequest(
  profile: PullRequestDiffProfile,
  checks: GitHubCheckRecord[],
  evidencePacks: EvidencePackRecord[]
): PullRequestAssessment {
  const failedChecks = checks.filter(isFailingGitHubCheck).length;
  const runningChecks = checks.filter(isRunningGitHubCheck).length;
  const rationale: string[] = [];
  const nextSteps: string[] = [];

  if (failedChecks > 0) {
    rationale.push(`${failedChecks} GitHub check(s) failed on the current PR head.`);
    nextSteps.push("Fix the failing GitHub checks before merge.");
    return {
      riskLevel: "high",
      mergeRecommendation: "blocking",
      rationale,
      nextSteps
    };
  }

  if (runningChecks > 0) {
    rationale.push(`${runningChecks} GitHub check(s) are still running.`);
    nextSteps.push("Wait for the remaining GitHub checks to complete.");
    return {
      riskLevel: "medium",
      mergeRecommendation: "caution",
      rationale,
      nextSteps
    };
  }

  if (profile.scope === "docs-only") {
    rationale.push("Diff scope is documentation-only.");
    rationale.push("No CAD or product runtime surface is touched.");
    nextSteps.push("Do an editorial pass if the content needs final wording validation.");
    return {
      riskLevel: "low",
      mergeRecommendation: "favorable",
      rationale,
      nextSteps
    };
  }

  if (profile.touchesCad) {
    rationale.push("CAD-affecting files are part of this PR.");
    if (evidencePacks.length === 0) {
      rationale.push("No tracked evidence pack was found for the current PR head.");
      nextSteps.push("Require a YiACAD/KiCad evidence pack before merge.");
      return {
        riskLevel: "high",
        mergeRecommendation: "blocking",
        rationale,
        nextSteps
      };
    }

    rationale.push(`${evidencePacks.length} evidence pack(s) are attached to the current PR head.`);
    nextSteps.push("Perform a final human CAD review on generated outputs before merge.");
    return {
      riskLevel: "medium",
      mergeRecommendation: "favorable",
      rationale,
      nextSteps
    };
  }

  if (profile.scope === "web" || profile.scope === "runtime" || profile.scope === "mixed") {
    rationale.push(`Diff scope is \`${profile.scope}\`.`);
    if (checks.length === 0) {
      rationale.push("No GitHub checks were loaded for the current PR head.");
      nextSteps.push("Run or load the GitHub checks before merge.");
      return {
        riskLevel: "medium",
        mergeRecommendation: "caution",
        rationale,
        nextSteps
      };
    }

    rationale.push("GitHub checks are green on the current PR head.");
    if (profile.touchesRuntime && evidencePacks.length === 0) {
      rationale.push("Runtime/CI files changed without a tracked evidence pack.");
      nextSteps.push("Publish an evidence pack for the changed runtime/CI lane.");
      return {
        riskLevel: "medium",
        mergeRecommendation: "caution",
        rationale,
        nextSteps
      };
    }

    nextSteps.push("Merge is acceptable if the owning surface review is complete.");
    return {
      riskLevel: "medium",
      mergeRecommendation: "favorable",
      rationale,
      nextSteps
    };
  }

  rationale.push("Diff classification stayed local-only.");
  nextSteps.push("Confirm the GitHub diff reflects the intended scope.");
  return {
    riskLevel: "medium",
    mergeRecommendation: "caution",
    rationale,
    nextSteps
  };
}

function buildPullRequestSummaryBody(
  pullRequest: PullRequestRecord,
  checks: GitHubCheckRecord[],
  evidencePacks: EvidencePackRecord[],
  ciRuns: CiRun[],
  artifacts: ArtifactRecord[]
) {
  const profile = classifyPullRequestDiff(pullRequest.changedFiles);
  const assessment = assessPullRequest(profile, checks, evidencePacks);
  const lines = [
    YIACAD_PR_SUMMARY_MARKER,
    `## YiACAD PR Summary`,
    ``,
    `- PR: #${pullRequest.id} ${pullRequest.title}`,
    `- Branch: \`${pullRequest.sourceBranch}\` -> \`${pullRequest.targetBranch}\``,
    `- Status: \`${pullRequest.status}\``,
    `- Change scope: \`${profile.scope}\``,
    `- Risk level: \`${assessment.riskLevel}\``,
    `- Merge recommendation: \`${assessment.mergeRecommendation}\``,
    `- Checks: ${pullRequest.checkSummary}`,
    `- Evidence packs: ${evidencePacks.length}`,
    `- Changed files: ${pullRequest.changedFiles.length}`,
    `- Artifacts: ${artifacts.length}`,
    ``
  ];

  if (assessment.rationale.length > 0) {
    lines.push(`### Assessment`, ``);
    for (const item of assessment.rationale) {
      lines.push(`- ${item}`);
    }
    lines.push(``);
  }

  if (checks.length > 0) {
    lines.push(`### GitHub Checks`, ``);
    for (const check of checks.slice(0, 6)) {
      lines.push(
        `- \`${check.status}\` ${check.name}${check.summary ? `: ${check.summary}` : ""}`
      );
    }
    lines.push(``);
  }

  if (evidencePacks.length > 0) {
    lines.push(`### Evidence Packs`, ``);
    for (const pack of evidencePacks.slice(0, 4)) {
      lines.push(
        `- \`${pack.status}\` ${pack.workflow}: ${pack.summary}${
          pack.detailsUrl ? ` ([run](${pack.detailsUrl}))` : ""
        }`
      );
    }
    lines.push(``);
  }

  if (ciRuns.length > 0) {
    lines.push(`### Latest YiACAD CI`, ``);
    for (const run of ciRuns.slice(0, 4)) {
      lines.push(
        `- \`${run.status}\` ${run.pipeline}: ${run.summary} (${run.artifactCount} artifact(s))`
      );
    }
    lines.push(``);
  }

  if (pullRequest.changedFiles.length > 0) {
    lines.push(`### Changed Files`, ``);
    for (const filePath of pullRequest.changedFiles.slice(0, 8)) {
      lines.push(`- \`${filePath}\``);
    }
    lines.push(``);
  }

  if (artifacts.length > 0) {
    lines.push(`### Artifact Preview`, ``);
    for (const artifact of artifacts.slice(0, 6)) {
      lines.push(
        `- ${artifact.label}${
          artifact.url ? ` ([open](${artifact.url}))` : ""
        }`
      );
    }
    lines.push(``);
  }

  if (assessment.nextSteps.length > 0) {
    lines.push(`### Next Steps`, ``);
    for (const step of assessment.nextSteps) {
      lines.push(`- ${step}`);
    }
    lines.push(``);
  }

  lines.push(
    `_Generated by YiACAD review lane from GitHub checks, workflow evidence packs, and local CI artifacts._`
  );

  return lines.join("\n");
}

function pipelineEngine(pipeline: string) {
  switch (pipeline) {
    case "kicad-headless":
    case "step-export":
      return "kicad";
    case "kibot":
      return "kibot";
    case "kiauto-checks":
      return "kiauto";
    default:
      return "yiacad";
  }
}

function normalizeCiRun(
  run: Partial<CiRun> & Pick<CiRun, "id" | "pipeline" | "status" | "queuedAt">
): CiRun {
  return {
    id: run.id,
    pipeline: run.pipeline,
    engine: typeof run.engine === "string" ? run.engine : pipelineEngine(run.pipeline),
    status: run.status,
    summary:
      typeof run.summary === "string" && run.summary.trim()
        ? run.summary
        : `${run.pipeline} ${run.status}`,
    degradedReasons: Array.isArray(run.degradedReasons)
      ? run.degradedReasons.filter(
          (item): item is string => typeof item === "string" && item.length > 0
        )
      : [],
    artifactCount: typeof run.artifactCount === "number" ? run.artifactCount : 0,
    queuedAt: run.queuedAt,
    startedAt: typeof run.startedAt === "string" ? run.startedAt : null,
    completedAt: typeof run.completedAt === "string" ? run.completedAt : null
  };
}

// ---------------------------------------------------------------------------
// GitHub PR API
// ---------------------------------------------------------------------------

const GITHUB_REPO =
  process.env.GITHUB_REPO ?? "electron-rare/Kill_LIFE";
const GITHUB_API = "https://api.github.com";
const GITHUB_REVIEW_PR_LIMIT = 10;
const GITHUB_REVIEW_RUN_LIMIT = 8;

function requireGitHubToken() {
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    throw new Error("GITHUB_TOKEN is not configured.");
  }

  return token;
}

async function fetchGitHubResponse(path: string, init?: RequestInit) {
  const token = requireGitHubToken();
  const extraHeaders =
    init?.headers && !Array.isArray(init.headers) && !(init.headers instanceof Headers)
      ? init.headers
      : {};

  return fetch(`${GITHUB_API}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      ...extraHeaders
    },
    signal: AbortSignal.timeout(8000)
  });
}

async function fetchGitHubJson<T>(path: string) {
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    return null;
  }

  try {
    const resp = await fetchGitHubResponse(path);

    if (!resp.ok) {
      return null;
    }

    return (await resp.json()) as T;
  } catch {
    return null;
  }
}

async function fetchGitHubReviewData(
  artifacts: ArtifactRecord[]
): Promise<GitHubReviewData | null> {
  const pulls = await fetchGitHubJson<Array<Record<string, unknown>>>(
    `/repos/${GITHUB_REPO}/pulls?state=open&per_page=${GITHUB_REVIEW_PR_LIMIT}`
  );

  if (!pulls) {
    return null;
  }

  const localArtifactIds = artifacts.map((artifact) => artifact.id);
  const perPull = await Promise.all(
    pulls.slice(0, GITHUB_REVIEW_PR_LIMIT).map(async (pullRequest) => {
      const number = numberValue(pullRequest.number) ?? 0;
      const id = String(number);
      const title = stringValue(pullRequest.title) ?? `PR #${id}`;
      const head = (pullRequest.head as Record<string, unknown> | undefined) ?? {};
      const base = (pullRequest.base as Record<string, unknown> | undefined) ?? {};
      const user = (pullRequest.user as Record<string, unknown> | undefined) ?? {};
      const headSha = stringValue(head.sha);
      const sourceBranch = stringValue(head.ref) ?? "";
      const targetBranch = stringValue(base.ref) ?? "main";
      const author = stringValue(user.login) ?? "unknown";
      const state = stringValue(pullRequest.state) ?? "open";
      const url = stringValue(pullRequest.html_url);
      const updatedAt = stringValue(pullRequest.updated_at);

      const [filesPayload, checksPayload, runsPayload] = await Promise.all([
        fetchGitHubJson<Array<Record<string, unknown>>>(
          `/repos/${GITHUB_REPO}/pulls/${number}/files?per_page=100`
        ),
        headSha
          ? fetchGitHubJson<{ check_runs?: Array<Record<string, unknown>> }>(
              `/repos/${GITHUB_REPO}/commits/${headSha}/check-runs?per_page=100`
            )
          : Promise.resolve(null),
        headSha
          ? fetchGitHubJson<{ workflow_runs?: Array<Record<string, unknown>> }>(
              `/repos/${GITHUB_REPO}/actions/runs?${new URLSearchParams({
                head_sha: headSha,
                event: "pull_request",
                per_page: String(GITHUB_REVIEW_RUN_LIMIT)
              }).toString()}`
            )
          : Promise.resolve(null)
      ]);

      const changedFiles = (filesPayload ?? [])
        .map((fileRecord) => stringValue(fileRecord.filename))
        .filter((value): value is string => Boolean(value));

      const normalizedChecks = ((checksPayload?.check_runs as Array<Record<string, unknown>> | undefined) ?? []).map(
        (checkRun) => {
          const status = normalizedCheckStatus(
            stringValue(checkRun.status),
            stringValue(checkRun.conclusion)
          );
          const output = (checkRun.output as Record<string, unknown> | undefined) ?? {};

          return {
            id: String(numberValue(checkRun.id) ?? `${id}-${stringValue(checkRun.name) ?? "check"}`),
            name: stringValue(checkRun.name) ?? "GitHub check",
            workflow: stringValue(
              ((checkRun.app as Record<string, unknown> | undefined) ?? {}).name
            ),
            status,
            conclusion: stringValue(checkRun.conclusion),
            summary: summarizeText(
              stringValue(output.title) ?? stringValue(output.summary),
              `${stringValue(checkRun.name) ?? "GitHub check"} ${status}`
            ),
            detailsUrl: stringValue(checkRun.details_url),
            completedAt: stringValue(checkRun.completed_at),
            headSha,
            pullRequestId: id
          } satisfies GitHubCheckRecord;
        }
      );

      const runs = ((runsPayload?.workflow_runs as Array<Record<string, unknown>> | undefined) ?? []).filter(
        (run) => {
          const workflowName = stringValue(run.name);
          return workflowName ? TRACKED_GITHUB_WORKFLOWS.has(workflowName) : false;
        }
      );

      const evidencePackCandidates: Array<EvidencePackRecord | null> = await Promise.all(
        runs.map(async (workflowRun) => {
          const runId = numberValue(workflowRun.id);
          if (runId === null) {
            return null;
          }

          const workflowName = stringValue(workflowRun.name) ?? "GitHub workflow";
          const artifactsPayload = await fetchGitHubJson<{ artifacts?: Array<Record<string, unknown>> }>(
            `/repos/${GITHUB_REPO}/actions/runs/${runId}/artifacts?per_page=100`
          );
          const workflowArtifacts = (artifactsPayload?.artifacts ?? []).map((artifact) => ({
            id: numberValue(artifact.id),
            name: stringValue(artifact.name),
            archiveDownloadUrl: stringValue(artifact.archive_download_url)
          }));
          const evidenceArtifact =
            workflowArtifacts.find(
              (artifact) => artifact.name && isEvidencePackArtifactName(artifact.name)
            ) ?? null;

          if (!evidenceArtifact && !TRACKED_GITHUB_WORKFLOWS.has(workflowName)) {
            return null;
          }

          const status = normalizedRunStatus(
            stringValue(workflowRun.status),
            stringValue(workflowRun.conclusion)
          );
          const artifactNames = workflowArtifacts
            .map((artifact) => artifact.name)
            .filter((value): value is string => Boolean(value));
          const summary = summarizeText(
            stringValue(workflowRun.display_title),
            `${workflowName} ${status}${artifactNames.length ? ` · ${artifactNames.length} artifact(s)` : ""}`
          );

          return {
            id: String(evidenceArtifact?.id ?? runId),
            name:
              evidenceArtifact?.name ??
              `${YIACAD_EVIDENCE_PACK_PREFIX}-${workflowName.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`,
            workflow: workflowName,
            status,
            conclusion: stringValue(workflowRun.conclusion),
            summary,
            detailsUrl: stringValue(workflowRun.html_url),
            artifactUrl: evidenceArtifact?.archiveDownloadUrl ?? stringValue(workflowRun.html_url),
            artifactNames,
            createdAt:
              stringValue(workflowRun.created_at) ??
              stringValue(workflowRun.run_started_at) ??
              new Date(0).toISOString(),
            updatedAt:
              stringValue(workflowRun.updated_at) ??
              stringValue(workflowRun.created_at) ??
              new Date(0).toISOString(),
            headSha,
            pullRequestId: id
          } as EvidencePackRecord;
        })
      );
      const evidencePacks = evidencePackCandidates.filter(
        (value): value is EvidencePackRecord => value !== null
      );

      const pullRequestChecks = normalizedChecks.filter((check) => check.pullRequestId === id);
      const checkSummary = buildCheckSummary(pullRequestChecks);
      const profile = classifyPullRequestDiff(changedFiles);
      const assessment = assessPullRequest(profile, pullRequestChecks, evidencePacks);
      const hasPcbDiff = changedFiles.some(
        (path) => path.endsWith(".kicad_pcb") || path.endsWith(".kicad_sch")
      );
      const hasDiagramDiff = changedFiles.some((path) => path.endsWith(".excalidraw"));
      const hasArtifactPreview =
        localArtifactIds.length > 0 ||
        evidencePacks.some((pack) => Boolean(pack.artifactUrl));

      return {
        pullRequest: {
          id,
          title,
          status: derivePullRequestStatus(state, pullRequestChecks, evidencePacks),
          author,
          hasPcbDiff,
          hasDiagramDiff,
          hasArtifactPreview,
          sourceBranch,
          targetBranch,
          url,
          updatedAt,
          headSha,
          checkSummary,
          changeScope: profile.scope,
          riskLevel: assessment.riskLevel,
          mergeRecommendation: assessment.mergeRecommendation,
          changedFiles,
          artifactIds: localArtifactIds,
          checkIds: pullRequestChecks.map((check) => check.id),
          evidencePackIds: evidencePacks.map((pack) => pack.id)
        } satisfies PullRequestRecord,
        githubChecks: pullRequestChecks,
        evidencePacks
      };
    })
  );

  return {
    pullRequests: perPull.map((item) => item.pullRequest),
    githubChecks: perPull
      .flatMap((item) => item.githubChecks)
      .sort((left, right) =>
        (right.completedAt ?? "").localeCompare(left.completedAt ?? "")
      ),
    evidencePacks: perPull
      .flatMap((item) => item.evidencePacks)
      .sort((left, right) => right.updatedAt.localeCompare(left.updatedAt))
  };
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
  const profile = classifyPullRequestDiff(changedFiles);
  const assessment = assessPullRequest(profile, [], []);
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
      url: null,
      updatedAt: null,
      headSha: head,
      checkSummary: "No GitHub checks loaded.",
      changeScope: profile.scope,
      riskLevel: assessment.riskLevel,
      mergeRecommendation: assessment.mergeRecommendation,
      changedFiles,
      artifactIds,
      checkIds: [],
      evidencePackIds: []
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
  const githubReviewData = await fetchGitHubReviewData(artifacts);
  const pullRequests =
    githubReviewData?.pullRequests ??
    derivePullRequests(
      gitState.branch,
      gitState.head,
      gitState.author,
      gitState.changedFiles,
      ciRuns,
      artifacts
    );
  const githubChecks = githubReviewData?.githubChecks ?? [];
  const evidencePacks = githubReviewData?.evidencePacks ?? [];

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
      artifacts,
      githubChecks,
      evidencePacks
    ),
    tree,
    diagrams,
    boardUrl,
    schematicUrl,
    ciRuns,
    artifacts,
    githubChecks,
    evidencePacks,
    pullRequests
  };
}

export async function publishPullRequestSummary(
  pullRequestId: string
): Promise<PublishPullRequestSummaryResult> {
  if (!/^\d+$/.test(pullRequestId)) {
    throw new Error("Pull request summary publishing requires a GitHub PR number.");
  }

  const project = await getProjectSnapshot();
  const pullRequest = project.pullRequests.find((record) => record.id === pullRequestId);

  if (!pullRequest) {
    throw new Error(`Pull request #${pullRequestId} is not available in the current review snapshot.`);
  }

  const checks = project.githubChecks.filter((check) =>
    pullRequest.checkIds.includes(check.id)
  );
  const evidencePacks = project.evidencePacks.filter((pack) =>
    pullRequest.evidencePackIds.includes(pack.id)
  );
  const linkedArtifacts = project.artifacts.filter((artifact) =>
    pullRequest.artifactIds.includes(artifact.id)
  );
  const body = buildPullRequestSummaryBody(
    pullRequest,
    checks,
    evidencePacks,
    project.ciRuns,
    linkedArtifacts
  );

  const comments =
    (await fetchGitHubJson<Array<Record<string, unknown>>>(
      `/repos/${GITHUB_REPO}/issues/${pullRequestId}/comments?per_page=100`
    )) ?? [];
  const existingComment = comments.find((comment) =>
    stringValue(comment.body)?.includes(YIACAD_PR_SUMMARY_MARKER)
  );
  const action: "created" | "updated" = existingComment ? "updated" : "created";
  const commentId = numberValue(existingComment?.id);
  const response = existingComment && commentId !== null
    ? await fetchGitHubResponse(`/repos/${GITHUB_REPO}/issues/comments/${commentId}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ body })
      })
    : await fetchGitHubResponse(`/repos/${GITHUB_REPO}/issues/${pullRequestId}/comments`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ body })
      });

  if (!response.ok) {
    const errorPayload = await response.text();
    throw new Error(
      `GitHub comment publish failed (${response.status}): ${errorPayload || response.statusText}`
    );
  }

  const payload = (await response.json()) as Record<string, unknown>;

  return {
    pullRequestId,
    commentUrl: stringValue(payload.html_url),
    action,
    summary:
      action === "updated"
        ? `Updated YiACAD summary comment on PR #${pullRequestId}.`
        : `Published YiACAD summary comment on PR #${pullRequestId}.`
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
