import type { ProjectSnapshot } from "@/lib/types";

export const PROJECT_SNAPSHOT_QUERY = `
  query ProjectShell {
    project {
      id
      name
      rootPath
      repoProvider
      repoVisibility
      repoBranch
      repoHead
      repoAuthor
      changedFiles
      reviewSummary
      boardUrl
      schematicUrl
      tree {
        path
        kind
      }
      diagrams {
        path
        name
        scene
      }
      ciRuns {
        id
        pipeline
        status
        queuedAt
      }
      artifacts {
        id
        label
        kind
        status
        url
        sourcePath
      }
      pullRequests {
        id
        title
        status
        author
        hasPcbDiff
        hasDiagramDiff
        hasArtifactPreview
        sourceBranch
        targetBranch
        changedFiles
        artifactIds
      }
    }
  }
`;

export async function requestGraphQL<T>(
  query: string,
  variables?: Record<string, unknown>
): Promise<T> {
  const response = await fetch("/api/graphql", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ query, variables })
  });

  const payload = (await response.json()) as {
    data?: T;
    errors?: Array<{ message: string }>;
  };

  if (!response.ok || payload.errors?.length) {
    throw new Error(payload.errors?.[0]?.message ?? "GraphQL request failed");
  }

  return payload.data as T;
}

export type ProjectQueryResult = {
  project: ProjectSnapshot;
};
