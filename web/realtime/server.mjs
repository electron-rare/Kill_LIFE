import { existsSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..");
const persistenceDir = resolve(root, "realtime", "data");
const serverEntryCandidates = [
  resolve(root, "node_modules", "@y", "websocket-server", "src", "server.js"),
  resolve(root, "node_modules", "y-websocket", "bin", "server.js")
];

const serverEntry = serverEntryCandidates.find((candidate) => {
  // Prefer the modern @y/websocket-server entrypoint when available.
  return existsSync(candidate);
}) ?? serverEntryCandidates[0];

mkdirSync(persistenceDir, { recursive: true });

const child = spawn(process.execPath, [serverEntry], {
  cwd: root,
  stdio: "inherit",
  env: {
    ...process.env,
    HOST: process.env.HOST ?? "0.0.0.0",
    PORT: process.env.PORT ?? "1234",
    YPERSISTENCE: process.env.YPERSISTENCE ?? persistenceDir
  }
});

child.on("exit", (code) => {
  process.exit(code ?? 0);
});
