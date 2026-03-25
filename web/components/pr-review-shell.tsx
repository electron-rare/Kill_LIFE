"use client";

import { useEffect, useState } from "react";

import {
  PROJECT_SNAPSHOT_QUERY,
  requestGraphQL,
  type ProjectQueryResult
} from "@/lib/graphql/client";
import type { CiRun, ProjectSnapshot } from "@/lib/types";

import { ProductNav } from "@/components/product-nav";

/* ---------- ERC/DRC helpers ---------- */

const EDA_PIPELINES = ["kibot", "erc", "drc", "kicad"];

function isEdaRun(run: CiRun): boolean {
  const lower = run.pipeline.toLowerCase();
  return EDA_PIPELINES.some((p) => lower.includes(p));
}

function statusColor(status: string): string {
  switch (status) {
    case "passed":
    case "success":
      return "#77f2c9";
    case "failed":
    case "error":
      return "#f27777";
    case "running":
      return "#77b8f2";
    default:
      return "#8da6c8";
  }
}

/* ---------- Ops summary ---------- */

type OpsHealth = {
  status: string;
  agents: number;
  uptime: string | null;
  message: string;
};

async function fetchOpsHealth(): Promise<OpsHealth> {
  try {
    const response = await fetch("/api/ops/health", { signal: AbortSignal.timeout(3000) });
    if (response.ok) {
      return (await response.json()) as OpsHealth;
    }
  } catch {
    // endpoint may not exist yet — fall through
  }
  return {
    status: "unavailable",
    agents: 0,
    uptime: null,
    message: "Ops health endpoint not reachable. Deploy Mascarade agents to enable."
  };
}

/* ---------- Component ---------- */

export function PrReviewShell() {
  const [project, setProject] = useState<ProjectSnapshot | null>(null);
  const [opsHealth, setOpsHealth] = useState<OpsHealth | null>(null);
  const [message, setMessage] = useState("Loading PR review...");

  useEffect(() => {
    let active = true;

    requestGraphQL<ProjectQueryResult>(PROJECT_SNAPSHOT_QUERY)
      .then((result) => {
        if (!active) return;
        setProject(result.project);
        setMessage("PR review cards loaded from the GraphQL gateway.");
      })
      .catch((error) => {
        if (!active) return;
        setMessage(error instanceof Error ? error.message : "Review load failed");
      });

    fetchOpsHealth().then((health) => {
      if (active) setOpsHealth(health);
    });

    return () => {
      active = false;
    };
  }, []);

  const changedFiles = project?.changedFiles ?? [];
  const edaRuns = (project?.ciRuns ?? []).filter(isEdaRun);
  const otherRuns = (project?.ciRuns ?? []).filter((r) => !isEdaRun(r));

  return (
    <main style={styles.page}>
      {/* ---- Header ---- */}
      <header style={styles.header}>
        <div>
          <p style={styles.eyebrow}>Killer feature lane</p>
          <h1 style={styles.title}>PR review</h1>
          <p style={styles.subtitle}>
            Read-only review surface: changed files, ERC/DRC outputs, and ops
            summary — backed by the GraphQL snapshot and Mascarade agents.
          </p>
        </div>
        <ProductNav />
      </header>

      {/* ---- Review-assist panels (new) ---- */}
      <section style={styles.assistGrid}>
        {/* -- Changed files -- */}
        <article style={styles.assistCard}>
          <h2 style={styles.assistTitle}>Changed files</h2>
          <p style={styles.assistCaption}>
            Working-tree changes in the project repo
            {project?.repoBranch ? ` (${project.repoBranch})` : ""}
          </p>
          <div style={styles.fileList}>
            {changedFiles.length === 0 ? (
              <p style={styles.muted}>Working tree clean.</p>
            ) : (
              changedFiles.map((filePath) => (
                <code key={filePath} style={styles.fileItem}>
                  {filePath}
                </code>
              ))
            )}
          </div>
        </article>

        {/* -- ERC/DRC results -- */}
        <article style={styles.assistCard}>
          <h2 style={styles.assistTitle}>ERC / DRC results</h2>
          <p style={styles.assistCaption}>
            KiCad electrical and design rule checks from EDA workers
          </p>
          <div style={styles.fileList}>
            {edaRuns.length === 0 ? (
              <p style={styles.muted}>
                No ERC/DRC runs recorded yet. Queue a KiBot pipeline to populate.
              </p>
            ) : (
              edaRuns.map((run) => (
                <div key={run.id} style={styles.runRow}>
                  <span
                    style={{
                      ...styles.runDot,
                      background: statusColor(run.status)
                    }}
                  />
                  <span style={styles.runPipeline}>{run.pipeline}</span>
                  <span style={styles.runStatus}>{run.status}</span>
                  <span style={styles.muted}>
                    {new Date(run.queuedAt).toLocaleDateString()}
                  </span>
                </div>
              ))
            )}
            {otherRuns.length > 0 ? (
              <p style={styles.muted}>
                + {otherRuns.length} non-EDA CI run{otherRuns.length > 1 ? "s" : ""}
              </p>
            ) : null}
          </div>
        </article>

        {/* -- Ops summary -- */}
        <article style={styles.assistCard}>
          <h2 style={styles.assistTitle}>Ops summary</h2>
          <p style={styles.assistCaption}>
            Mascarade agent health and deployment state
          </p>
          <div style={styles.fileList}>
            {opsHealth === null ? (
              <p style={styles.muted}>Checking ops health...</p>
            ) : (
              <>
                <div style={styles.runRow}>
                  <span
                    style={{
                      ...styles.runDot,
                      background: statusColor(
                        opsHealth.status === "ok" ? "passed" : opsHealth.status
                      )
                    }}
                  />
                  <span>Status: {opsHealth.status}</span>
                </div>
                <div style={styles.opsDetail}>
                  <span>Agents: {opsHealth.agents}</span>
                  {opsHealth.uptime ? <span>Uptime: {opsHealth.uptime}</span> : null}
                </div>
                <p style={styles.muted}>{opsHealth.message}</p>
              </>
            )}
          </div>
        </article>
      </section>

      {/* ---- Existing PR cards ---- */}
      <section style={styles.grid}>
        {(project?.pullRequests ?? []).map((pullRequest) => {
          const linkedArtifacts = (project?.artifacts ?? []).filter((artifact) =>
            pullRequest.artifactIds.includes(artifact.id)
          );

          return (
            <article key={pullRequest.id} style={styles.card}>
              <header style={styles.cardHeader}>
                <div>
                  <strong>{pullRequest.title}</strong>
                  <div style={styles.caption}>
                    {pullRequest.sourceBranch} → {pullRequest.targetBranch} · {pullRequest.id}
                  </div>
                </div>
                <span style={styles.status}>{pullRequest.status}</span>
              </header>
              <div style={styles.tags}>
                <span style={styles.tag}>
                  {pullRequest.hasPcbDiff ? "KiCad diff ready" : "KiCad diff pending"}
                </span>
                <span style={styles.tag}>
                  {pullRequest.hasDiagramDiff
                    ? "Excalidraw diff ready"
                    : "Excalidraw diff pending"}
                </span>
                <span style={styles.tag}>
                  {pullRequest.hasArtifactPreview
                    ? "Artifact preview ready"
                    : "Artifact preview pending"}
                </span>
              </div>
              <div style={styles.gridMini}>
                <section style={styles.diffPanel}>
                  <h2 style={styles.panelTitle}>Changed files</h2>
                  <div style={styles.fileList}>
                    {pullRequest.changedFiles.map((filePath) => (
                      <code key={filePath} style={styles.fileItem}>
                        {filePath}
                      </code>
                    ))}
                    {pullRequest.changedFiles.length === 0 ? (
                      <p style={styles.text}>Working tree clean for `web/project`.</p>
                    ) : null}
                  </div>
                </section>
                <section style={styles.diffPanel}>
                  <h2 style={styles.panelTitle}>Artifact previews</h2>
                  <div style={styles.fileList}>
                    {linkedArtifacts.map((artifact) =>
                      artifact.url ? (
                        <a
                          key={artifact.id}
                          href={artifact.url}
                          style={styles.link}
                          target="_blank"
                          rel="noreferrer"
                        >
                          {artifact.label}
                        </a>
                      ) : (
                        <span key={artifact.id} style={styles.text}>
                          {artifact.label} pending route
                        </span>
                      )
                    )}
                    {linkedArtifacts.length === 0 ? (
                      <p style={styles.text}>
                        No web-served artifacts yet for this review.
                      </p>
                    ) : null}
                  </div>
                </section>
              </div>
            </article>
          );
        })}
      </section>

      <footer style={styles.footer}>{message}</footer>
    </main>
  );
}

/* ---------- Styles ---------- */

const styles: Record<string, React.CSSProperties> = {
  page: {
    minHeight: "100vh",
    padding: "32px",
    display: "grid",
    gap: "24px"
  },
  header: {
    display: "flex",
    justifyContent: "space-between",
    gap: "24px",
    alignItems: "flex-start"
  },
  eyebrow: {
    margin: 0,
    color: "#8da6c8",
    textTransform: "uppercase",
    letterSpacing: "0.18em",
    fontSize: "0.75rem"
  },
  title: {
    margin: "8px 0 12px",
    fontSize: "clamp(2rem, 4vw, 3.4rem)",
    lineHeight: 1
  },
  subtitle: {
    margin: 0,
    color: "#b7c8e3",
    maxWidth: "64ch"
  },

  /* Review-assist panels */
  assistGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
    gap: "18px"
  },
  assistCard: {
    padding: "20px",
    borderRadius: "24px",
    background: "rgba(12, 22, 39, 0.84)",
    border: "1px solid rgba(149, 188, 255, 0.18)"
  },
  assistTitle: {
    margin: "0 0 4px",
    fontSize: "1.05rem"
  },
  assistCaption: {
    margin: "0 0 12px",
    color: "#8da6c8",
    fontSize: "0.82rem"
  },

  /* Run rows (ERC/DRC + ops) */
  runRow: {
    display: "flex",
    alignItems: "center",
    gap: "8px",
    padding: "8px 10px",
    borderRadius: "12px",
    background: "rgba(149, 188, 255, 0.08)"
  },
  runDot: {
    width: "8px",
    height: "8px",
    borderRadius: "50%",
    flexShrink: 0
  },
  runPipeline: {
    fontWeight: 600
  },
  runStatus: {
    color: "#b7c8e3"
  },
  opsDetail: {
    display: "flex",
    gap: "16px",
    padding: "8px 10px",
    borderRadius: "12px",
    background: "rgba(149, 188, 255, 0.08)",
    color: "#d9ebff"
  },

  /* Shared / existing */
  muted: {
    margin: 0,
    color: "#8da6c8",
    fontSize: "0.88rem"
  },
  grid: {
    display: "grid",
    gap: "18px"
  },
  card: {
    padding: "20px",
    borderRadius: "24px",
    background: "rgba(12, 22, 39, 0.84)",
    border: "1px solid rgba(149, 188, 255, 0.18)"
  },
  cardHeader: {
    display: "flex",
    justifyContent: "space-between",
    gap: "12px",
    alignItems: "center"
  },
  caption: {
    color: "#8da6c8",
    marginTop: "4px"
  },
  status: {
    padding: "8px 12px",
    borderRadius: "999px",
    background: "rgba(119, 242, 201, 0.16)",
    color: "#77f2c9"
  },
  tags: {
    display: "flex",
    gap: "10px",
    flexWrap: "wrap",
    marginTop: "14px",
    marginBottom: "16px"
  },
  tag: {
    padding: "8px 12px",
    borderRadius: "999px",
    background: "rgba(5, 12, 24, 0.76)",
    color: "#d9ebff"
  },
  gridMini: {
    display: "grid",
    gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
    gap: "14px"
  },
  diffPanel: {
    borderRadius: "18px",
    background: "rgba(5, 12, 24, 0.76)",
    padding: "16px"
  },
  panelTitle: {
    marginTop: 0,
    marginBottom: "8px"
  },
  text: {
    margin: 0,
    color: "#b7c8e3"
  },
  fileList: {
    display: "grid",
    gap: "8px"
  },
  fileItem: {
    padding: "8px 10px",
    borderRadius: "12px",
    background: "rgba(149, 188, 255, 0.08)",
    color: "#d9ebff",
    overflowX: "auto"
  },
  link: {
    color: "#77f2c9",
    textDecoration: "none"
  },
  footer: {
    color: "#8da6c8",
    fontFamily: "var(--font-mono), monospace"
  }
};
