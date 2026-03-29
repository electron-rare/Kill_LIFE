import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

import { Worker } from "bullmq";

const here = dirname(fileURLToPath(import.meta.url));
const webRoot = resolve(here, "..");
const repoRoot = resolve(webRoot, "..");
const ciRoot = resolve(webRoot, "project", ".ci");
const runsFile = join(ciRoot, "runs.json");
const artifactsFile = join(ciRoot, "artifacts.json");
const logsRoot = join(ciRoot, "logs");
const queueName = process.env.EDA_QUEUE_NAME ?? "yiacad-eda";

function pipelineEngine(pipeline) {
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

function uniqueStrings(values) {
  return [...new Set(values.filter((value) => typeof value === "string" && value.length > 0))];
}

function redisConnection() {
  const url = new URL(process.env.REDIS_URL ?? "redis://127.0.0.1:6379");
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

async function ensureCiFiles() {
  await mkdir(ciRoot, { recursive: true });
  await mkdir(logsRoot, { recursive: true });

  for (const [path, emptyValue] of [
    [runsFile, "[]\n"],
    [artifactsFile, "[]\n"]
  ]) {
    try {
      await readFile(path, "utf8");
    } catch {
      await writeFile(path, emptyValue, "utf8");
    }
  }
}

async function readJson(path, fallback) {
  try {
    return JSON.parse(await readFile(path, "utf8"));
  } catch {
    return fallback;
  }
}

async function updateRun(runId, patch) {
  const runs = await readJson(runsFile, []);
  const nextRuns = runs.map((run) =>
    run.id === runId ? { ...run, ...patch } : run
  );
  await writeFile(runsFile, JSON.stringify(nextRuns, null, 2), "utf8");
}

async function appendArtifacts(records) {
  const current = await readJson(artifactsFile, []);
  const byId = new Map(current.map((item) => [item.id, item]));

  for (const record of records) {
    byId.set(record.id, record);
  }

  await writeFile(
    artifactsFile,
    JSON.stringify([...byId.values()], null, 2),
    "utf8"
  );
}

function runCommand(command, args, logPrefix) {
  return new Promise((resolveRun) => {
    const child = spawn(command, args, {
      cwd: repoRoot,
      env: process.env
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("close", async (code) => {
      await writeFile(`${logPrefix}.stdout.log`, stdout, "utf8");
      await writeFile(`${logPrefix}.stderr.log`, stderr, "utf8");
      resolveRun({ code: code ?? 1, stdout, stderr });
    });
  });
}

function parseJsonOutput(stdout) {
  try {
    return JSON.parse(stdout);
  } catch {
    return null;
  }
}

function mapYiacadArtifacts(runId, payload) {
  const artifacts = Array.isArray(payload?.artifacts) ? payload.artifacts : [];

  return artifacts.map((artifact, index) => ({
    id: `${runId}-${index}-${artifact.label ?? artifact.path ?? "artifact"}`,
    label: artifact.label ?? artifact.path ?? "artifact",
    kind: artifact.kind ?? "report",
    status: payload?.status ?? "ready",
    url: artifact.path ?? null,
    sourcePath: artifact.path ?? null,
    runId,
    summary: payload?.summary ?? null
  }));
}

function parsePayloadOrThrow(result, failureMessage) {
  const payload = parseJsonOutput(result.stdout);
  if (payload) {
    return payload;
  }

  if (result.code !== 0) {
    throw new Error(result.stderr || result.stdout || failureMessage);
  }

  return {
    status: "success",
    summary: failureMessage,
    degraded_reasons: [],
    artifacts: []
  };
}

function finalizeRunResult(pipeline, payloads, artifacts) {
  const statuses = payloads
    .map((payload) => payload?.status)
    .filter((status) => typeof status === "string");

  let status = "success";
  if (statuses.includes("blocked")) {
    status = "blocked";
  } else if (statuses.includes("degraded")) {
    status = "degraded";
  } else if (statuses.includes("failed")) {
    status = "failed";
  }

  const summaries = payloads
    .map((payload) => (typeof payload?.summary === "string" ? payload.summary.trim() : ""))
    .filter(Boolean);

  const degradedReasons = uniqueStrings(
    payloads.flatMap((payload) =>
      Array.isArray(payload?.degraded_reasons) ? payload.degraded_reasons : []
    )
  );

  return {
    status,
    engine: pipelineEngine(pipeline),
    summary: summaries.join(" | ") || `${pipeline} completed through YiACAD.`,
    degradedReasons,
    artifactCount: artifacts.length,
    artifacts
  };
}

async function processKicadHeadless(job, logPrefix) {
  const sourcePath =
    job.data.boardPath ?? job.data.schematicPath ?? job.data.projectRoot;
  const ercDrc = await runCommand(
    "python3",
    [
      resolve(repoRoot, "tools/cad/yiacad_backend_client.py"),
      "--surface",
      "yiacad-web",
      "kicad-erc-drc",
      "--source-path",
      sourcePath,
      "--json-output"
    ],
    `${logPrefix}-ercdrc`
  );

  const ercDrcPayload = parsePayloadOrThrow(ercDrc, "kicad-headless ERC/DRC failed");
  const artifacts = mapYiacadArtifacts(job.id, ercDrcPayload);
  const payloads = [ercDrcPayload];

  if (job.data.boardPath || job.data.freecadDocumentPath) {
    const sync = await runCommand(
      "python3",
      [
        resolve(repoRoot, "tools/cad/yiacad_backend_client.py"),
        "--surface",
        "yiacad-web",
        "ecad-mcad-sync",
        "--source-path",
        sourcePath,
        "--json-output"
      ],
      `${logPrefix}-sync`
    );

    const syncPayload = parseJsonOutput(sync.stdout);
    if (syncPayload) {
      payloads.push(syncPayload);
      artifacts.push(...mapYiacadArtifacts(`${job.id}-sync`, syncPayload));
    } else if (sync.code !== 0) {
      throw new Error(sync.stderr || "kicad-headless ECAD/MCAD sync failed");
    }
  }

  return finalizeRunResult(job.name, payloads, artifacts);
}

async function processKibot(job, logPrefix) {
  const localConfig = resolve(webRoot, "project/pcb/kibot.yaml");
  const sourcePath =
    job.data.boardPath ?? job.data.schematicPath ?? job.data.projectRoot;
  const kibot = await runCommand(
    "python3",
    [
      resolve(repoRoot, "tools/cad/yiacad_backend_client.py"),
      "--surface",
      "yiacad-web",
      "manufacturing-package",
      "--source-path",
      sourcePath,
      "--kibot-config",
      process.env.KIBOT_CONFIG || localConfig,
      "--json-output"
    ],
    `${logPrefix}-kibot`
  );

  const payload = parsePayloadOrThrow(kibot, "YiACAD manufacturing package worker failed");
  const artifacts = mapYiacadArtifacts(job.id, payload);
  return finalizeRunResult(job.name, [payload], artifacts);
}

async function processKiauto(job, logPrefix) {
  const result = await runCommand(
    "python3",
    [
      resolve(repoRoot, "tools/cad/yiacad_backend_client.py"),
      "--surface",
      "yiacad-web",
      "kiauto-checks",
      "--source-path",
      job.data.boardPath ?? job.data.schematicPath ?? job.data.projectRoot,
      "--json-output"
    ],
    `${logPrefix}-kiauto`
  );

  const payload = parsePayloadOrThrow(result, "YiACAD KiAuto worker failed");
  const artifacts = mapYiacadArtifacts(job.id, payload);
  return finalizeRunResult(job.name, [payload], artifacts);
}

async function processStepExport(job, logPrefix) {
  const sourcePath =
    job.data.boardPath ?? job.data.schematicPath ?? job.data.projectRoot;
  const sync = await runCommand(
    "python3",
    [
      resolve(repoRoot, "tools/cad/yiacad_backend_client.py"),
      "--surface",
      "yiacad-web",
      "ecad-mcad-sync",
      "--source-path",
      sourcePath,
      "--json-output"
    ],
    `${logPrefix}-step`
  );

  const payload = parsePayloadOrThrow(sync, "STEP export failed");
  const artifacts = mapYiacadArtifacts(job.id, payload);
  return finalizeRunResult(job.name, [payload], artifacts);
}

await ensureCiFiles();

const worker = new Worker(
  queueName,
  async (job) => {
    const logPrefix = resolve(logsRoot, `${job.id}-${job.name}`);
    await updateRun(job.id, {
      status: "running",
      engine: pipelineEngine(job.name),
      summary: `Running ${job.name} through the YiACAD backend.`,
      startedAt: new Date().toISOString()
    });

    let result;

    if (job.name === "kicad-headless") {
      result = await processKicadHeadless(job, logPrefix);
    } else if (job.name === "kibot") {
      result = await processKibot(job, logPrefix);
    } else if (job.name === "kiauto-checks") {
      result = await processKiauto(job, logPrefix);
    } else if (job.name === "step-export") {
      result = await processStepExport(job, logPrefix);
    } else {
      throw new Error(`Unknown EDA pipeline: ${job.name}`);
    }

    await appendArtifacts(result.artifacts);
    await updateRun(job.id, {
      status: result.status,
      engine: result.engine,
      summary: result.summary,
      degradedReasons: result.degradedReasons,
      artifactCount: result.artifactCount,
      completedAt: new Date().toISOString()
    });
    return result;
  },
  {
    connection: redisConnection()
  }
);

worker.on("failed", async (job, error) => {
  if (!job) {
    return;
  }

  await updateRun(job.id, {
    status: "failed",
    summary: error?.message || "worker failed",
    completedAt: new Date().toISOString()
  });
  await writeFile(
    resolve(logsRoot, `${job.id}-${job.name}.error.log`),
    error?.stack || error?.message || "worker failed",
    "utf8"
  );
});

worker.on("ready", () => {
  console.log(`EDA worker ready on queue ${queueName}`);
});
