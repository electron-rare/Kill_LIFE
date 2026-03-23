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

function commandExists(command) {
  return new Promise((resolveExists) => {
    const child = spawn("sh", ["-lc", `command -v ${command}`], {
      stdio: "ignore"
    });
    child.on("close", (code) => resolveExists(code === 0));
  });
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
    status: "ready",
    url: artifact.path ?? null,
    sourcePath: artifact.path ?? null
  }));
}

function mapFabArtifacts(runId, payload) {
  const items = [
    ["gerber", "Gerber bundle", payload?.gerber_dir],
    ["bom", "BOM export", payload?.bom_file],
    ["drill", "Drill file", payload?.drill_file],
    ["drc", "DRC report", payload?.drc_report]
  ];

  return items
    .filter(([, , path]) => Boolean(path))
    .map(([kind, label, path]) => ({
      id: `${runId}-${kind}`,
      label,
      kind,
      status: "ready",
      url: path,
      sourcePath: path
    }));
}

async function processKicadHeadless(job, logPrefix) {
  const sourcePath =
    job.data.boardPath ?? job.data.schematicPath ?? job.data.projectRoot;
  const ercDrc = await runCommand(
    "python3",
    [
      resolve(repoRoot, "tools/cad/yiacad_native_ops.py"),
      "kicad-erc-drc",
      "--source-path",
      sourcePath,
      "--json-output"
    ],
    `${logPrefix}-ercdrc`
  );

  if (ercDrc.code !== 0) {
    throw new Error(ercDrc.stderr || "kicad-headless ERC/DRC failed");
  }

  const ercDrcPayload = parseJsonOutput(ercDrc.stdout);
  const artifacts = mapYiacadArtifacts(job.id, ercDrcPayload);

  if (job.data.boardPath || job.data.freecadDocumentPath) {
    const sync = await runCommand(
      "python3",
      [
        resolve(repoRoot, "tools/cad/yiacad_native_ops.py"),
        "ecad-mcad-sync",
        "--source-path",
        sourcePath,
        "--json-output"
      ],
      `${logPrefix}-sync`
    );

    if (sync.code === 0) {
      artifacts.push(...mapYiacadArtifacts(`${job.id}-sync`, parseJsonOutput(sync.stdout)));
    }
  }

  return artifacts;
}

async function processKibot(job, logPrefix) {
  const localConfig = resolve(webRoot, "project/pcb/kibot.yaml");
  const hasKibot = await commandExists(process.env.KIBOT_BIN || "kibot");

  if (hasKibot && job.data.boardPath) {
    const kibot = await runCommand(
      process.env.KIBOT_BIN || "kibot",
      [
        "-b",
        job.data.boardPath,
        "-c",
        process.env.KIBOT_CONFIG || localConfig,
        "-d",
        resolve(repoRoot, "artifacts", "web-kibot", String(job.id))
      ],
      `${logPrefix}-kibot`
    );

    if (kibot.code === 0) {
      return [
        {
          id: `${job.id}-kibot`,
      label: "KiBot output directory",
      kind: "kibot",
      status: "ready",
      url: resolve(repoRoot, "artifacts", "web-kibot", String(job.id)),
      sourcePath: resolve(repoRoot, "artifacts", "web-kibot", String(job.id))
    }
  ];
    }
  }

  const fab = await runCommand(
    "bash",
    [
      resolve(repoRoot, "tools/cockpit/fab_package_tui.sh"),
      "--action",
      "build",
      "--json",
      "--mode",
      "live",
      "--schematic",
      job.data.schematicPath || "",
      "--board",
      job.data.boardPath || ""
    ],
    `${logPrefix}-fab`
  );

  if (fab.code !== 0) {
    throw new Error(fab.stderr || "kibot/fab package worker failed");
  }

  return mapFabArtifacts(job.id, parseJsonOutput(fab.stdout));
}

async function processKiauto(job, logPrefix) {
  const kiautoBin = process.env.KIAUTO_BIN || "kiauto";
  const hasKiAuto = await commandExists(kiautoBin);

  if (!hasKiAuto || !job.data.boardPath) {
    throw new Error("KiAuto is not configured. Set KIAUTO_BIN and provide a board.");
  }

  const result = await runCommand(
    kiautoBin,
    ["--help"],
    `${logPrefix}-kiauto`
  );

  if (result.code !== 0) {
    throw new Error(result.stderr || "KiAuto invocation failed");
  }

  return [
    {
      id: `${job.id}-kiauto`,
      label: "KiAuto checks",
      kind: "kiauto",
      status: "ready",
      url: `${logPrefix}-kiauto.stdout.log`,
      sourcePath: `${logPrefix}-kiauto.stdout.log`
    }
  ];
}

async function processStepExport(job, logPrefix) {
  const sourcePath =
    job.data.boardPath ?? job.data.schematicPath ?? job.data.projectRoot;
  const sync = await runCommand(
    "python3",
    [
      resolve(repoRoot, "tools/cad/yiacad_native_ops.py"),
      "ecad-mcad-sync",
      "--source-path",
      sourcePath,
      "--json-output"
    ],
    `${logPrefix}-step`
  );

  if (sync.code !== 0) {
    throw new Error(sync.stderr || "STEP export failed");
  }

  return mapYiacadArtifacts(job.id, parseJsonOutput(sync.stdout));
}

await ensureCiFiles();

const worker = new Worker(
  queueName,
  async (job) => {
    const logPrefix = resolve(logsRoot, `${job.id}-${job.name}`);
    await updateRun(job.id, { status: "running" });

    let artifacts = [];

    if (job.name === "kicad-headless") {
      artifacts = await processKicadHeadless(job, logPrefix);
    } else if (job.name === "kibot") {
      artifacts = await processKibot(job, logPrefix);
    } else if (job.name === "kiauto-checks") {
      artifacts = await processKiauto(job, logPrefix);
    } else if (job.name === "step-export") {
      artifacts = await processStepExport(job, logPrefix);
    } else {
      throw new Error(`Unknown EDA pipeline: ${job.name}`);
    }

    await appendArtifacts(artifacts);
    await updateRun(job.id, { status: "completed" });
    return { artifacts };
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
    status: "failed"
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
