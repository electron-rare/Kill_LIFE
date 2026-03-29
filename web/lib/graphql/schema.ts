import { createSchema } from "graphql-yoga";

import { enqueueCi } from "@/lib/ci-enqueue";
import {
  getProjectSnapshot,
  publishPullRequestSummary,
  saveDiagram
} from "@/lib/project-store";

export const schema = createSchema({
  typeDefs: /* GraphQL */ `
    type ProjectNode {
      path: String!
      kind: String!
    }

    type Diagram {
      path: String!
      name: String!
      scene: String!
    }

    type CiRun {
      id: ID!
      pipeline: String!
      engine: String!
      status: String!
      summary: String!
      degradedReasons: [String!]!
      artifactCount: Int!
      queuedAt: String!
      startedAt: String
      completedAt: String
    }

    type Artifact {
      id: ID!
      label: String!
      kind: String!
      status: String!
      url: String
      sourcePath: String
      runId: String
      summary: String
    }

    type GitHubCheck {
      id: ID!
      name: String!
      workflow: String
      status: String!
      conclusion: String
      summary: String!
      detailsUrl: String
      completedAt: String
      headSha: String
      pullRequestId: String
    }

    type EvidencePack {
      id: ID!
      name: String!
      workflow: String!
      status: String!
      conclusion: String
      summary: String!
      detailsUrl: String
      artifactUrl: String
      artifactNames: [String!]!
      createdAt: String!
      updatedAt: String!
      headSha: String
      pullRequestId: String
    }

    type PullRequest {
      id: ID!
      title: String!
      status: String!
      author: String!
      hasPcbDiff: Boolean!
      hasDiagramDiff: Boolean!
      hasArtifactPreview: Boolean!
      sourceBranch: String!
      targetBranch: String!
      url: String
      updatedAt: String
      headSha: String
      checkSummary: String!
      changeScope: String!
      riskLevel: String!
      mergeRecommendation: String!
      changedFiles: [String!]!
      artifactIds: [String!]!
      checkIds: [String!]!
      evidencePackIds: [String!]!
    }

    type Project {
      id: ID!
      name: String!
      rootPath: String!
      repoProvider: String!
      repoVisibility: String!
      repoBranch: String
      repoHead: String
      repoAuthor: String
      changedFiles: [String!]!
      reviewSummary: String!
      tree: [ProjectNode!]!
      diagrams: [Diagram!]!
      boardUrl: String
      schematicUrl: String
      ciRuns: [CiRun!]!
      artifacts: [Artifact!]!
      githubChecks: [GitHubCheck!]!
      evidencePacks: [EvidencePack!]!
      pullRequests: [PullRequest!]!
    }

    type Query {
      project(id: ID = "yiacad-demo"): Project!
    }

    type PublishPullRequestSummaryResult {
      pullRequestId: ID!
      commentUrl: String
      action: String!
      summary: String!
    }

    type Mutation {
      saveDiagram(path: String!, scene: String!): Diagram!
      enqueueCi(projectId: ID = "yiacad-demo", pipeline: String!): CiRun!
      publishPullRequestSummary(pullRequestId: ID!): PublishPullRequestSummaryResult!
    }
  `,
  resolvers: {
    Query: {
      project: async () => getProjectSnapshot()
    },
    Mutation: {
      saveDiagram: async (
        _: unknown,
        args: { path: string; scene: string }
      ) => saveDiagram(args.path, args.scene),
      enqueueCi: async (_: unknown, args: { pipeline: string }) =>
        enqueueCi(args.pipeline),
      publishPullRequestSummary: async (
        _: unknown,
        args: { pullRequestId: string }
      ) => publishPullRequestSummary(args.pullRequestId)
    }
  }
});
