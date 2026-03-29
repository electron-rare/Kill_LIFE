import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { NextResponse } from "next/server";

export const runtime = "nodejs";

type RuntimePayload = {
  generated_at?: string;
  surfaces?: {
    infra_vps?: {
      status?: string;
      summary_short?: string;
      degraded_reasons?: string[];
      services?: unknown[];
      path?: string;
    };
  };
  sources?: {
    infra_vps?: {
      service_count?: number;
      path?: string;
    };
  };
};

function runtimeArtifactPath(): string {
  return (
    process.env.RUNTIME_GATEWAY_JSON_PATH ??
    resolve(process.cwd(), "..", "artifacts", "cockpit", "runtime_mcp_ia_gateway_latest.json")
  );
}

export async function GET() {
  const artifactPath = runtimeArtifactPath();

  if (!existsSync(artifactPath)) {
    return NextResponse.json({
      status: "unavailable",
      service_count: 0,
      degraded_reasons: ["infra-vps-runtime-artifact-missing"],
      summary_short:
        "Runtime gateway artifact missing. Run: bash tools/cockpit/runtime_ai_gateway.sh --action status --json > artifacts/cockpit/runtime_mcp_ia_gateway_latest.json",
      path: artifactPath,
      generated_at: null
    });
  }

  try {
    const payload = JSON.parse(readFileSync(artifactPath, "utf-8")) as RuntimePayload;
    const surface = payload.surfaces?.infra_vps;
    const source = payload.sources?.infra_vps;

    return NextResponse.json({
      status: surface?.status ?? "unavailable",
      service_count:
        typeof source?.service_count === "number"
          ? source.service_count
          : Array.isArray(surface?.services)
            ? surface.services.length
            : 0,
      degraded_reasons: Array.isArray(surface?.degraded_reasons)
        ? surface.degraded_reasons
        : [],
      summary_short: surface?.summary_short ?? "infra_vps surface unavailable",
      path: surface?.path ?? source?.path ?? artifactPath,
      generated_at: payload.generated_at ?? null
    });
  } catch (error) {
    return NextResponse.json({
      status: "unavailable",
      service_count: 0,
      degraded_reasons: ["infra-vps-runtime-artifact-invalid-json"],
      summary_short: "Failed to parse runtime gateway artifact.",
      path: artifactPath,
      generated_at: null,
      error: error instanceof Error ? error.message : "unknown"
    });
  }
}
