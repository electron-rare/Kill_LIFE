import { execFile } from "node:child_process";
import { relative } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export type GitProjectState = {
  branch: string | null;
  head: string | null;
  author: string | null;
  changedFiles: string[];
  clean: boolean;
};

async function gitCapture(
  repoRoot: string,
  args: string[]
): Promise<string | null> {
  try {
    const { stdout } = await execFileAsync("git", ["-C", repoRoot, ...args]);
    const value = stdout.trim();
    return value || null;
  } catch {
    return null;
  }
}

function normalizeChangedPath(line: string) {
  const candidate = line.trim().slice(3).trim();
  const normalized = candidate.includes("->")
    ? candidate.split("->").pop()?.trim() ?? candidate
    : candidate;

  return normalized || null;
}

export async function getGitProjectState(
  repoRoot: string,
  projectRoot: string
): Promise<GitProjectState> {
  const scope = relative(repoRoot, projectRoot) || ".";
  const [branch, head, author, statusOutput] = await Promise.all([
    gitCapture(repoRoot, ["branch", "--show-current"]),
    gitCapture(repoRoot, ["rev-parse", "--short", "HEAD"]),
    gitCapture(repoRoot, ["config", "user.name"]),
    gitCapture(repoRoot, ["status", "--short", "--", scope])
  ]);

  const changedFiles = Array.from(
    new Set(
      (statusOutput ?? "")
        .split("\n")
        .map(normalizeChangedPath)
        .filter((value): value is string => Boolean(value))
        .sort((left, right) => left.localeCompare(right))
    )
  );

  return {
    branch,
    head,
    author,
    changedFiles,
    clean: changedFiles.length === 0
  };
}
