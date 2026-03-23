import { readFile } from "node:fs/promises";
import { extname } from "node:path";

import { resolveProjectPath } from "@/lib/project-store";

export const runtime = "nodejs";

const CONTENT_TYPES: Record<string, string> = {
  ".excalidraw": "application/json; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".kicad_pcb": "text/plain; charset=utf-8",
  ".kicad_prj": "text/plain; charset=utf-8",
  ".kicad_pro": "text/plain; charset=utf-8",
  ".kicad_sch": "text/plain; charset=utf-8",
  ".md": "text/markdown; charset=utf-8",
  ".step": "model/step",
  ".stp": "model/step"
};

export async function GET(
  _request: Request,
  { params }: { params: { segments: string[] } }
) {
  try {
    const filePath = resolveProjectPath(params.segments);
    const contents = await readFile(filePath);
    const extension = extname(filePath).toLowerCase();

    return new Response(contents, {
      headers: {
        "Content-Type":
          CONTENT_TYPES[extension] ?? "application/octet-stream"
      }
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "project file unavailable";

    return Response.json(
      {
        error: message
      },
      { status: 404 }
    );
  }
}
