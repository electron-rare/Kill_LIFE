/**
 * T-AI-323 — Intelligence health aggregator for Lot 23 (YiACAD Git-EDA Platform).
 *
 * Surfaces queue / worker / realtime status into a single structured payload
 * consumable by intelligence_tui and runtime_ai_gateway.
 */

export type ServiceStatus = "ok" | "degraded" | "unavailable";

export interface QueueHealth {
  status: ServiceStatus;
  waiting: number;
  active: number;
  failed: number;
  latencyMs?: number;
  reason?: string;
}

export interface WorkerHealth {
  status: ServiceStatus;
  running: boolean;
  lastJobId?: string;
  lastJobMs?: number;
  reason?: string;
}

export interface RealtimeHealth {
  status: ServiceStatus;
  connected: boolean;
  clients: number;
  roomCount: number;
}

export interface WebPlatformHealth {
  timestamp: string;
  overall: ServiceStatus;
  queue: QueueHealth;
  worker: WorkerHealth;
  realtime: RealtimeHealth;
}

const QUEUE_API = process.env.EDA_QUEUE_URL ?? "http://localhost:3000/api/ops/queue";
const WORKER_API = process.env.EDA_WORKER_URL ?? "http://localhost:3000/api/ops/worker";
const REALTIME_API = process.env.YJS_HEALTH_URL ?? "http://localhost:1234/health";

async function fetchJson<T>(url: string, timeoutMs = 1500): Promise<T | null> {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(timeoutMs) });
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

async function getQueueHealth(): Promise<QueueHealth> {
  const data = await fetchJson<Record<string, unknown>>(QUEUE_API);
  if (!data) return { status: "unavailable", waiting: 0, active: 0, failed: 0 };
  const waiting =
    typeof data.waiting === "number"
      ? data.waiting
      : typeof data.depth === "number"
        ? data.depth
        : 0;
  const active = typeof data.active === "number" ? data.active : 0;
  const failed = typeof data.failed === "number" ? data.failed : 0;
  const latencyMs = typeof data.latencyMs === "number" ? data.latencyMs : undefined;
  const reason = typeof data.reason === "string" ? data.reason : undefined;
  const statusValue = typeof data.status === "string" ? data.status : "";
  const status: ServiceStatus =
    statusValue === "down" ? "unavailable" : statusValue === "degraded" || failed > 10 ? "degraded" : "ok";
  return { status, waiting, active, failed, latencyMs, reason };
}

async function getWorkerHealth(): Promise<WorkerHealth> {
  const data = await fetchJson<Record<string, unknown>>(WORKER_API);
  if (!data) return { status: "unavailable", running: false };
  const running = data.running === true;
  const lastJobId = typeof data.lastJobId === "string" ? data.lastJobId : undefined;
  const lastJobMs = typeof data.lastJobMs === "number" ? data.lastJobMs : undefined;
  const reason = typeof data.reason === "string" ? data.reason : undefined;
  const statusValue = typeof data.status === "string" ? data.status : "";
  const status: ServiceStatus =
    statusValue === "down" ? "unavailable" : statusValue === "degraded" || !running ? "degraded" : "ok";
  return { status, running, lastJobId, lastJobMs, reason };
}

async function getRealtimeHealth(): Promise<RealtimeHealth> {
  const data = await fetchJson<Record<string, unknown>>(REALTIME_API);
  if (!data) return { status: "unavailable", connected: false, clients: 0, roomCount: 0 };
  const clients = typeof data.clients === "number" ? data.clients : 0;
  const roomCount = typeof data.rooms === "number" ? data.rooms : 0;
  return { status: "ok", connected: true, clients, roomCount };
}

function roll(statuses: ServiceStatus[]): ServiceStatus {
  if (statuses.includes("unavailable")) return "degraded";
  if (statuses.includes("degraded")) return "degraded";
  return "ok";
}

/**
 * Aggregate health from queue, worker, and realtime services.
 * Safe to call from Next.js API routes (server-side only).
 */
export async function getWebPlatformHealth(): Promise<WebPlatformHealth> {
  const [queue, worker, realtime] = await Promise.all([
    getQueueHealth(),
    getWorkerHealth(),
    getRealtimeHealth(),
  ]);

  return {
    timestamp: new Date().toISOString(),
    overall: roll([queue.status, worker.status, realtime.status]),
    queue,
    worker,
    realtime,
  };
}
