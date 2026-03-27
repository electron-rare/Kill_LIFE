/**
 * T-AI-325 — Git snapshot policy for Excalidraw-Yjs collaborative editing.
 *
 * Defines when Yjs realtime state is promoted to a Git commit, and how
 * conflicts between concurrent editors are resolved.
 *
 * Design decisions:
 * - Realtime sync (Yjs) is ephemeral: it keeps clients in sync but does NOT
 *   automatically write to Git.
 * - Git commits are always explicit, triggered by a deliberate user action
 *   ("Save to Git") or by a CI/agent event.
 * - Conflict resolution: last-write-wins within the Yjs CRDT (automatic),
 *   Git-level conflicts are resolved by the snapshot author.
 */

export type SnapshotTrigger =
  | "manual_save"       // user clicked "Save to Git"
  | "ci_trigger"        // CI pipeline requests a snapshot before running ERC/DRC
  | "agent_request";    // intelligence agent captures state for review

export interface GitSnapshotPolicy {
  /** Who may trigger a Git snapshot. */
  allowedTriggers: SnapshotTrigger[];

  /**
   * Minimum time (ms) between automatic snapshots from the same session.
   * Manual saves are not rate-limited.
   */
  minIntervalMs: number;

  /**
   * If true, the snapshot includes the full Yjs document state as a
   * base64 blob in the commit message (for forensics).
   */
  embedYjsState: boolean;

  /**
   * Commit message template. Tokens: {trigger}, {author}, {timestamp}, {room}.
   */
  commitMessageTemplate: string;
}

/** Default policy for YiACAD collaborative sessions. */
export const DEFAULT_POLICY: GitSnapshotPolicy = {
  allowedTriggers: ["manual_save", "ci_trigger", "agent_request"],
  minIntervalMs: 30_000, // 30s floor on non-manual snapshots
  embedYjsState: false,
  commitMessageTemplate: "chore(yiacad): snapshot [{trigger}] by {author} at {timestamp} — room {room}",
};

export function buildCommitMessage(
  policy: GitSnapshotPolicy,
  ctx: { trigger: SnapshotTrigger; author: string; room: string },
): string {
  return policy.commitMessageTemplate
    .replace("{trigger}", ctx.trigger)
    .replace("{author}", ctx.author)
    .replace("{timestamp}", new Date().toISOString())
    .replace("{room}", ctx.room);
}

/**
 * Returns true if a snapshot may be taken given the last snapshot timestamp.
 * Manual saves always pass; other triggers are rate-limited.
 */
export function canSnapshot(
  trigger: SnapshotTrigger,
  policy: GitSnapshotPolicy,
  lastSnapshotAt: number | null,
): boolean {
  if (!policy.allowedTriggers.includes(trigger)) return false;
  if (trigger === "manual_save") return true;
  if (lastSnapshotAt === null) return true;
  return Date.now() - lastSnapshotAt >= policy.minIntervalMs;
}
