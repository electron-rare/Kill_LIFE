import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { extname, join, resolve } from "node:path";

import { enqueueEdaJob } from "@/lib/eda-queue";

type CiRun = {
  id: string;
  pipeline: string;
  engine: string;
  status: string;
  summary: string;
  degradedReasons: string[];
  artifactCount: number;
  queuedAt: string;
  startedAt: string | null;
  completedAt: string | null;
};

const APP_ROOT = process.cwd();
const PROJECT_ROOT = join(APP_ROOT, "project");
const CI_ROOT = join(PROJECT_ROOT, ".ci");
const CI_RUNS_FILE = join(CI_ROOT, "runs.json");

async function readJson<T>(path: string, fallback: T): Promise<T> {
  try {
    return JSON.parse(await readFile(path, "utf8")) as T;
  } catch {
    return fallback;
  }
}

async function writeCiRuns(runs: CiRun[]) {
  await mkdir(CI_ROOT, { recursive: true });
  await writeFile(CI_RUNS_FILE, JSON.stringify(runs, null, 2), "utf8");
}

function pipelineEngine(pipeline: string) {
  switch (pipeline) {
    case "kicad-headless":
    case "step-export":
      return "kicad";
    case "kibot":
      return "kibot";
    case "kiauto-checks":
      return "kiauto";
    default:
      return "yiacad";
  }
}

async function findFirstProjectFilePath(
  absoluteDir: string,
  extensions: string[]
): Promise<string | null> {
  async function walk(dir: string): Promise<string | null> {
    const items = await readdir(dir, { withFileTypes: true });

    for (const item of items.sort((left, right) => left.name.localeCompare(right.name))) {
      const nextPath = join(dir, item.name);

      if (item.isDirectory()) {
        const nested = await walk(nextPath);
        if (nested) {
          return nested;
        }
        continue;
      }

      if (extensions.includes(extname(item.name).toLowerCase())) {
        return resolve(nextPath);
      }
    }

    return null;
  }

  return walk(absoluteDir);
}

export async function enqueueCi(pipeline: string) {
  const nextRun: CiRun = {
    id: `${Date.now()}`,
    pipeline,
    engine: pipelineEngine(pipeline),
    status: "queued",
    summary: `Queued ${pipeline} in the YiACAD CI orchestrator.`,
    degradedReasons: [],
    artifactCount: 0,
    queuedAt: new Date().toISOString(),
    startedAt: null,
    completedAt: null
  };
  const queue = await readJson<CiRun[]>(CI_RUNS_FILE, []);
  await writeCiRuns([nextRun, ...queue]);

  try {
    await enqueueEdaJob({
      runId: nextRun.id,
      pipeline: pipeline as
        | "kicad-headless"
        | "kibot"
        | "kiauto-checks"
        | "step-export",
      projectRoot: PROJECT_ROOT,
      boardPath: await findFirstProjectFilePath(PROJECT_ROOT, [".kicad_pcb"]),
      schematicPath: await findFirstProjectFilePath(PROJECT_ROOT, [".kicad_sch"]),
      freecadDocumentPath: await findFirstProjectFilePath(PROJECT_ROOT, [".fcstd"])
    });
  } catch (error) {
    await writeCiRuns([
      {
        ...nextRun,
        status: "queue_failed",
        summary:
          error instanceof Error
            ? `Queue enqueue failed: ${error.message}`
            : "Queue enqueue failed."
      },
      ...queue
    ]);

    if (error instanceof Error) {
      throw new Error(`Redis queue enqueue failed: ${error.message}`);
    }

    throw new Error("Redis queue enqueue failed.");
  }

  return nextRun;
}
