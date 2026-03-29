import { NextResponse } from "next/server";

import { probeQueue } from "@/lib/intelligence/ops-health";

export const runtime = "nodejs";

export async function GET() {
  return NextResponse.json(await probeQueue());
}
