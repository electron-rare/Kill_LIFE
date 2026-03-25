import { NextResponse } from "next/server";

export const runtime = "nodejs";

/**
 * Lightweight proxy to the Mascarade agent health endpoint.
 * If the agent cluster is unreachable, returns a degraded-but-valid payload
 * so the review-assist surface always renders.
 */
export async function GET() {
  const mascaradeUrl =
    process.env.MASCARADE_HEALTH_URL ?? "http://localhost:8042/health";

  try {
    const upstream = await fetch(mascaradeUrl, {
      signal: AbortSignal.timeout(2000)
    });

    if (upstream.ok) {
      const data = (await upstream.json()) as Record<string, unknown>;
      return NextResponse.json({
        status: "ok",
        agents: typeof data.agents === "number" ? data.agents : 1,
        uptime: typeof data.uptime === "string" ? data.uptime : null,
        message:
          typeof data.message === "string"
            ? data.message
            : "Mascarade agents healthy."
      });
    }

    return NextResponse.json({
      status: "degraded",
      agents: 0,
      uptime: null,
      message: `Upstream returned ${upstream.status}.`
    });
  } catch {
    return NextResponse.json({
      status: "unavailable",
      agents: 0,
      uptime: null,
      message:
        "Mascarade health endpoint not reachable. Deploy agents to enable ops summary."
    });
  }
}
