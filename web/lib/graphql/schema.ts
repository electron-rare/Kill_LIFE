import { createSchema } from "graphql-yoga";

import { enqueueCi } from "@/lib/ci-enqueue";
import { getProjectSnapshot, saveDiagram } from "@/lib/project-store";

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
      status: String!
      queuedAt: String!
    }

    type Artifact {
      id: ID!
      label: String!
      kind: String!
      status: String!
      url: String
      sourcePath: String
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
      changedFiles: [String!]!
      artifactIds: [String!]!
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
      pullRequests: [PullRequest!]!
    }

    type Query {
      project(id: ID = "yiacad-demo"): Project!
    }

    type Mutation {
      saveDiagram(path: String!, scene: String!): Diagram!
      enqueueCi(projectId: ID = "yiacad-demo", pipeline: String!): CiRun!
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
        enqueueCi(args.pipeline)
    }
  }
});
