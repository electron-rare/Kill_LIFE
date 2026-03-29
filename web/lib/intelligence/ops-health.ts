import { readFile } from "node:fs/promises";
import { join } from "node:path";

import { getEdaQueue } from "@/lib/eda-queue";

type ProbeStatus = "up" | "degraded" | "down";

const CI_ROOT = join(process.cwd(), "project", ".ci");
const WORKER_HEALTH_FILE = join(CI_ROOT, "worker-health.json");

function queueFailureReason(error: unknown): string {
  const message = String(error ?? "");
  if (message.includes("REDIS_URL is not configured")) {
    return "redis-env-missing";
  }
  return "redis-unreachable";
}

export async function probeQueue(): Promise<Record<string, unknown>> {
  try {
    const queue = getEdaQueue();
    const counts = await queue.getJobCounts("wait", "active", "failed");
    const depth = counts.wait ?? 0;
    const active = counts.active ?? 0;
    const failed = counts.failed ?? 0;
    const status: ProbeStatus = failed > 10 ? "degraded" : "up";
    return {
      status,
      reason: status === "degraded" ? "queue-failures-high" : "queue-ready",
      depth,
      waiting: depth,
      active,
      failed
    };
  } catch (error) {
    return {
      status: "down",
      reason: queueFailureReason(error),
      detail: String(error ?? "")
    };
  }
}

export async function probeWorker(staleAfterMs = 180_000): Promise<Record<string, unknown>> {
  try {
    const raw = await readFile(WORKER_HEALTH_FILE, "utf8");
    const data = JSON.parse(raw) as Record<string, unknown>;
    const updatedAt = typeof data.updatedAt === "string" ? data.updatedAt : "";
    const updatedMs = updatedAt ? Date.parse(updatedAt) : NaN;
    const ageMs = Number.isNaN(updatedMs) ? null : Math.max(0, Date.now() - updatedMs);
    if (ageMs !== null && ageMs > staleAfterMs) {
      return {
        status: "degraded",
        reason: "worker-stale",
        running: data.running === true,
        lastJobId: typeof data.lastJobId === "string" ? data.lastJobId : undefined,
        lastJobMs: typeof data.lastJobMs === "number" ? data.lastJobMs : undefined,
        updatedAt,
        ageMs
      };
    }
    return {
      status: data.running === true ? "up" : "degraded",
      reason: data.running === true ? "worker-running" : "worker-idle",
      running: data.running === true,
      lastJobId: typeof data.lastJobId === "string" ? data.lastJobId : undefined,
      lastJobMs: typeof data.lastJobMs === "number" ? data.lastJobMs : undefined,
      updatedAt,
      ageMs
    };
  } catch {
    return {
      status: "down",
      reason: "worker-absent",
      running: false
    };
  }
}
