import { NextResponse } from "next/server";
import { getEdaQueue } from "@/lib/eda-queue";

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

async function probeQueue(): Promise<ProbeResult> {
  try {
    const queue = getEdaQueue();
    const counts = await queue.getJobCounts("wait", "active", "failed");
    const depth = counts.wait ?? 0;
    const active = counts.active ?? 0;
    const failed = counts.failed ?? 0;
    const status = failed > 10 ? "degraded" : "up";
    return { status, detail: depth, ...(active ? { active } : {}), ...(failed ? { failed } : {}) } as ProbeResult & Record<string, unknown>;
  } catch (err) {
    return { status: "down", detail: String(err) };
  }
}

export async function GET() {
  const yjsUrl =
    process.env.YJS_WS_HTTP_URL ??
    `http://localhost:${process.env.YJS_WS_PORT ?? "1234"}/`;
  const nextUrl = `http://localhost:${process.env.PORT ?? "3000"}/`;

  const [nextProbe, yjsProbe, queueProbe] = await Promise.all([
    probeUrl(nextUrl),
    probeUrl(yjsUrl),
    probeQueue(),
  ]);

  const probes = {
    "next-js": nextProbe,
    "yjs-realtime": yjsProbe,
    "eda-queue": queueProbe,
  };

  const upCount = Object.values(probes).filter((p) => p.status === "up").length;
  const total = Object.keys(probes).length;
  const status =
    upCount === total ? "up" : upCount === 0 ? "down" : "degraded";

  return NextResponse.json({ status, up_count: upCount, total, probes });
}
