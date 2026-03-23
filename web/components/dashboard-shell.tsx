"use client";

import { useEffect, useState } from "react";

import {
  PROJECT_SNAPSHOT_QUERY,
  requestGraphQL,
  type ProjectQueryResult
} from "@/lib/graphql/client";
import type { ProjectSnapshot } from "@/lib/types";

import { ProductNav } from "@/components/product-nav";

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
