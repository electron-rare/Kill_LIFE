export type ProjectNode = {
  path: string;
  kind: string;
};

export type Diagram = {
  path: string;
  name: string;
  scene: string;
};

export type CiRun = {
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

export type ArtifactRecord = {
  id: string;
  label: string;
  kind: string;
  status: string;
  url: string | null;
  sourcePath: string | null;
  runId: string | null;
  summary: string | null;
};

export type GitHubCheckRecord = {
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

export type EvidencePackRecord = {
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

export type PullRequestRecord = {
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

export type ProjectSnapshot = {
  id: string;
  name: string;
  rootPath: string;
  repoProvider: string;
  repoVisibility: string;
  repoBranch: string | null;
  repoHead: string | null;
  repoAuthor: string | null;
  changedFiles: string[];
  reviewSummary: string;
  boardUrl: string | null;
  schematicUrl: string | null;
  tree: ProjectNode[];
  diagrams: Diagram[];
  ciRuns: CiRun[];
  artifacts: ArtifactRecord[];
  githubChecks: GitHubCheckRecord[];
  evidencePacks: EvidencePackRecord[];
  pullRequests: PullRequestRecord[];
};

export type PublishPullRequestSummaryResult = {
  pullRequestId: string;
  commentUrl: string | null;
  action: string;
  summary: string;
};
