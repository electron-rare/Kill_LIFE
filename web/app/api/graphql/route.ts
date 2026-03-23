import { createYoga } from "graphql-yoga";

import { schema } from "@/lib/graphql/schema";

export const runtime = "nodejs";

const yoga = createYoga({
  schema,
  graphqlEndpoint: "/api/graphql",
  fetchAPI: { Request, Response, Headers }
});

export async function GET(request: Request) {
  return yoga.handle(request, {});
}

export async function POST(request: Request) {
  return yoga.handle(request, {});
}
