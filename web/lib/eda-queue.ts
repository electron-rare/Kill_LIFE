import { Queue } from "bullmq";

export type EdaPipeline =
  | "kicad-headless"
  | "kibot"
  | "kiauto-checks"
  | "step-export";

export type EdaJobPayload = {
  runId: string;
  pipeline: EdaPipeline;
  projectRoot: string;
  boardPath: string | null;
  schematicPath: string | null;
  freecadDocumentPath: string | null;
};

const QUEUE_NAME = process.env.EDA_QUEUE_NAME ?? "yiacad-eda";

let queue: Queue<EdaJobPayload> | null = null;

function redisConnection() {
  const rawUrl = process.env.REDIS_URL;
  if (!rawUrl) {
    throw new Error("REDIS_URL is not configured.");
  }
  const url = new URL(rawUrl);
  const db = url.pathname && url.pathname !== "/" ? Number(url.pathname.slice(1)) : 0;

  return {
    host: url.hostname,
    port: Number(url.port || 6379),
    username: url.username || undefined,
    password: url.password || undefined,
    db,
    tls: url.protocol === "rediss:" ? {} : undefined
  };
}

export function getEdaQueue() {
  if (!queue) {
    queue = new Queue<EdaJobPayload>(QUEUE_NAME, {
      connection: redisConnection()
    });
  }

  return queue;
}

export async function enqueueEdaJob(payload: EdaJobPayload) {
  const job = await getEdaQueue().add(payload.pipeline, payload, {
    jobId: payload.runId,
    removeOnComplete: 100,
    removeOnFail: 500
  });

  return `${job.id}`;
}
