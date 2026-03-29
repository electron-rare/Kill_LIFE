"use client";

import { useEffect, useState } from "react";

import {
  PROJECT_SNAPSHOT_QUERY,
  requestGraphQL,
  type ProjectQueryResult
} from "@/lib/graphql/client";
import type { ProjectSnapshot } from "@/lib/types";

import { ProductNav } from "@/components/product-nav";

type InfraVpsStatus = {
  status: string;
  service_count: number;
  degraded_reasons: string[];
  summary_short: string;
  path: string | null;
  generated_at: string | null;
};

function infraStatusLabel(status: string | undefined): string {
  if (status === "ready" || status === "ok") {
    return "READY";
  }
  if (status === "blocked") {
    return "BLOCKED";
  }
  if (status === "degraded") {
    return "DEGRADED";
  }
  return "UNAVAILABLE";
}

function infraStatusStyle(status: string | undefined): React.CSSProperties {
  if (status === "ready" || status === "ok") {
    return styles.badgeReady;
  }
  if (status === "blocked") {
    return styles.badgeBlocked;
  }
  if (status === "degraded") {
    return styles.badgeDegraded;
  }
  return styles.badgeUnknown;
}

function metricValue(project: ProjectSnapshot | null, key: string) {
  if (!project) {
    return "...";
  }

  switch (key) {
    case "files":
      return `${project.tree.length}`;
    case "prs":
      return `${project.pullRequests.length}`;
    case "runs":
      return `${project.ciRuns.length}`;
    case "artifacts":
      return `${project.artifacts.length}`;
    default:
      return "0";
  }
}

export function DashboardShell() {
  const [project, setProject] = useState<ProjectSnapshot | null>(null);
  const [infraVps, setInfraVps] = useState<InfraVpsStatus | null>(null);
  const [message, setMessage] = useState("Loading dashboard...");

  useEffect(() => {
    let active = true;

    requestGraphQL<ProjectQueryResult>(PROJECT_SNAPSHOT_QUERY)
      .then((result) => {
        if (!active) {
          return;
        }

        setProject(result.project);
        setMessage("Dashboard synced from the GraphQL gateway.");
      })
      .catch((error) => {
        if (!active) {
          return;
        }

        setMessage(
          error instanceof Error ? error.message : "Dashboard load failed"
        );
      });

    fetch("/api/ops/infra-vps", { signal: AbortSignal.timeout(3000) })
      .then(async (response) => {
        if (!active) {
          return;
        }
        if (!response.ok) {
          throw new Error(`Infra VPS endpoint returned ${response.status}`);
        }
        const payload = (await response.json()) as InfraVpsStatus;
        setInfraVps(payload);
      })
      .catch(() => {
        if (!active) {
          return;
        }
        setInfraVps({
          status: "unavailable",
          service_count: 0,
          degraded_reasons: ["infra-vps-endpoint-unreachable"],
          summary_short: "Infra VPS status endpoint not reachable.",
          path: null,
          generated_at: null
        });
      });

    return () => {
      active = false;
    };
  }, []);

  return (
    <main style={styles.page}>
      <header style={styles.hero}>
        <div>
          <p style={styles.eyebrow}>Git-based EDA platform</p>
          <h1 style={styles.title}>Project dashboard</h1>
          <p style={styles.subtitle}>
            Git remains the source of truth. GraphQL aggregates project state,
            CI, artifacts, PR review, and diagram metadata for the web product.
          </p>
        </div>
        <ProductNav />
      </header>

      <section style={styles.metrics}>
        {[
          ["files", "Project files"],
          ["prs", "Pull requests"],
          ["runs", "CI runs"],
          ["artifacts", "Artifacts"]
        ].map(([key, label]) => (
          <article key={key} style={styles.metricCard}>
            <strong style={styles.metricValue}>{metricValue(project, key)}</strong>
            <span style={styles.metricLabel}>{label}</span>
          </article>
        ))}
      </section>

      <section style={styles.grid}>
        <article style={styles.panel}>
          <h2 style={styles.panelTitle}>Core platform</h2>
          <ul style={styles.list}>
            <li>{project?.repoProvider ?? "gitea/gitlab"} self-host</li>
            <li>{project?.repoVisibility ?? "multi-tenant repo-per-project"}</li>
            <li>Git-tracked `.excalidraw` and KiCad inputs</li>
          </ul>
        </article>
        <article style={styles.panel}>
          <h2 style={styles.panelTitle}>EDA engine</h2>
          <ul style={styles.list}>
            <li>KiCad headless workers</li>
            <li>KiBot outputs for Gerber, BOM, STEP, PDF</li>
            <li>KiAuto gates for DRC and ERC</li>
          </ul>
        </article>
        <article style={styles.panel}>
          <h2 style={styles.panelTitle}>Realtime layer</h2>
          <ul style={styles.list}>
            <li>Yjs / CRDT room transport</li>
            <li>Dedicated websocket server</li>
            <li>Presence, comments, collaboration as the next app lot</li>
          </ul>
        </article>
        <article style={styles.panel}>
          <h2 style={styles.panelTitle}>Parts and data</h2>
          <ul style={styles.list}>
            <li>Git as source of truth for EDA files</li>
            <li>Postgres metadata + internal graph model</li>
            <li>Elastic or Typesense + Redis cache for parts</li>
          </ul>
        </article>
      </section>

      <section style={styles.bottomGrid}>
        <article style={styles.panel}>
          <h2 style={styles.panelTitle}>Roadmap</h2>
          <ul style={styles.list}>
            <li>Phase 1: Git + KiBot CI + viewer + artifacts</li>
            <li>Phase 2: collab, comments, parts DB, PR previews</li>
            <li>Phase 3: browser editing, simulation, AI assist</li>
          </ul>
        </article>
        <article style={styles.panel}>
          <h2 style={styles.panelTitle}>Frontend surfaces</h2>
          <ul style={styles.list}>
            <li>Project dashboard</li>
            <li>Diagram editor backed by Excalidraw JSON</li>
            <li>PCB viewer backed by KiCanvas</li>
            <li>PR review with KiCad and diagram diffs</li>
          </ul>
        </article>
        <article style={styles.panel}>
          <h2 style={styles.panelTitle}>Infra VPS</h2>
          <div style={styles.badgeRow}>
            <span style={infraStatusStyle(infraVps?.status)}>
              {infraStatusLabel(infraVps?.status)}
            </span>
            <span style={styles.badgeMeta}>
              {infraVps?.generated_at
                ? `Updated: ${new Date(infraVps.generated_at).toLocaleString()}`
                : "Updated: n/a"}
            </span>
          </div>
          <ul style={styles.list}>
            <li>Status: {infraVps?.status ?? "loading"}</li>
            <li>Services: {infraVps?.service_count ?? 0}</li>
            <li>Summary: {infraVps?.summary_short ?? "Loading runtime surface..."}</li>
            <li>Reasons: {(infraVps?.degraded_reasons ?? []).join(", ") || "none"}</li>
          </ul>
        </article>
      </section>

      <footer style={styles.footer}>{message}</footer>
    </main>
  );
}

const styles: Record<string, React.CSSProperties> = {
  page: {
    minHeight: "100vh",
    padding: "32px",
    display: "grid",
    gap: "24px"
  },
  hero: {
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
    fontSize: "clamp(2rem, 4vw, 3.8rem)",
    lineHeight: 1
  },
  subtitle: {
    margin: 0,
    maxWidth: "68ch",
    color: "#b7c8e3"
  },
  metrics: {
    display: "grid",
    gap: "16px",
    gridTemplateColumns: "repeat(4, minmax(0, 1fr))"
  },
  metricCard: {
    display: "grid",
    gap: "6px",
    padding: "20px",
    borderRadius: "24px",
    background: "rgba(12, 22, 39, 0.84)",
    border: "1px solid rgba(149, 188, 255, 0.18)"
  },
  metricValue: {
    fontSize: "2rem"
  },
  metricLabel: {
    color: "#8da6c8"
  },
  grid: {
    display: "grid",
    gap: "18px",
    gridTemplateColumns: "repeat(2, minmax(0, 1fr))"
  },
  bottomGrid: {
    display: "grid",
    gap: "18px",
    gridTemplateColumns: "repeat(2, minmax(0, 1fr))"
  },
  panel: {
    padding: "20px",
    borderRadius: "24px",
    background: "rgba(12, 22, 39, 0.84)",
    border: "1px solid rgba(149, 188, 255, 0.18)"
  },
  panelTitle: {
    marginTop: 0
  },
  badgeRow: {
    display: "flex",
    alignItems: "center",
    gap: "12px",
    marginBottom: "10px"
  },
  badgeMeta: {
    color: "#8da6c8",
    fontSize: "0.82rem"
  },
  badgeReady: {
    display: "inline-block",
    padding: "4px 10px",
    borderRadius: "999px",
    background: "rgba(57, 211, 132, 0.2)",
    color: "#7df0ba",
    border: "1px solid rgba(57, 211, 132, 0.45)",
    fontWeight: 700,
    letterSpacing: "0.04em",
    fontSize: "0.74rem"
  },
  badgeDegraded: {
    display: "inline-block",
    padding: "4px 10px",
    borderRadius: "999px",
    background: "rgba(242, 199, 119, 0.2)",
    color: "#ffd88f",
    border: "1px solid rgba(242, 199, 119, 0.45)",
    fontWeight: 700,
    letterSpacing: "0.04em",
    fontSize: "0.74rem"
  },
  badgeBlocked: {
    display: "inline-block",
    padding: "4px 10px",
    borderRadius: "999px",
    background: "rgba(242, 119, 119, 0.22)",
    color: "#ff9f9f",
    border: "1px solid rgba(242, 119, 119, 0.45)",
    fontWeight: 700,
    letterSpacing: "0.04em",
    fontSize: "0.74rem"
  },
  badgeUnknown: {
    display: "inline-block",
    padding: "4px 10px",
    borderRadius: "999px",
    background: "rgba(141, 166, 200, 0.2)",
    color: "#c7d5ea",
    border: "1px solid rgba(141, 166, 200, 0.45)",
    fontWeight: 700,
    letterSpacing: "0.04em",
    fontSize: "0.74rem"
  },
  list: {
    margin: 0,
    paddingLeft: "18px",
    display: "grid",
    gap: "8px",
    color: "#c7d5ea"
  },
  footer: {
    color: "#8da6c8",
    fontFamily: "var(--font-mono), monospace"
  }
};
