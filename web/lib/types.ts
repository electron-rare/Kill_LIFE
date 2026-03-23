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
  status: string;
  queuedAt: string;
};

export type ArtifactRecord = {
  id: string;
  label: string;
  kind: string;
  status: string;
  url: string | null;
  sourcePath: string | null;
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
  changedFiles: string[];
  artifactIds: string[];
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
  pullRequests: PullRequestRecord[];
};
