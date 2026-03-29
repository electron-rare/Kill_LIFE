import { NextResponse } from "next/server";

import { probeQueue, probeWorker } from "@/lib/intelligence/ops-health";

export const runtime = "nodejs";

type ProbeResult = {
  status: "up" | "degraded" | "down";
  latency_ms?: number;
  detail?: string | number;
};

async function probeUrl(url: string, timeoutMs = 1500): Promise<ProbeResult> {
  const t0 = Date.now();
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(timeoutMs) });
    return { status: res.ok ? "up" : "degraded", latency_ms: Date.now() - t0 };
  } catch {
    return { status: "down", latency_ms: Date.now() - t0 };
  }
}

export async function GET() {
  const yjsUrl =
    process.env.YJS_WS_HTTP_URL ??
    `http://localhost:${process.env.YJS_WS_PORT ?? "1234"}/`;
  const nextUrl = `http://localhost:${process.env.PORT ?? "3000"}/`;

  const [nextProbe, yjsProbe, queueProbe, workerProbe] = await Promise.all([
    probeUrl(nextUrl),
    probeUrl(yjsUrl),
    probeQueue(),
    probeWorker(),
  ]);

  const probes = {
    "next-js": nextProbe,
    "yjs-realtime": yjsProbe,
    "eda-queue": queueProbe,
    "eda-worker": workerProbe,
  };

  const upCount = Object.values(probes).filter((p) => p.status === "up").length;
  const total = Object.keys(probes).length;
  const status =
    upCount === total ? "up" : upCount === 0 ? "down" : "degraded";

  return NextResponse.json({ status, up_count: upCount, total, probes });
}
