"use client";

import { useEffect, useState } from "react";

import {
  PROJECT_SNAPSHOT_QUERY,
  requestGraphQL,
  type ProjectQueryResult
} from "@/lib/graphql/client";
import type { ProjectSnapshot } from "@/lib/types";

import { KiCanvasViewer } from "@/components/kicanvas-viewer";
import { ProductNav } from "@/components/product-nav";

export function PcbWorkbench() {
  const [project, setProject] = useState<ProjectSnapshot | null>(null);
  const [message, setMessage] = useState("Loading PCB viewer...");

  useEffect(() => {
    let active = true;

    requestGraphQL<ProjectQueryResult>(PROJECT_SNAPSHOT_QUERY)
      .then((result) => {
        if (!active) {
          return;
        }

        setProject(result.project);
        setMessage("PCB viewer wired to the GraphQL project service.");
      })
      .catch((error) => {
        if (!active) {
          return;
        }

        setMessage(error instanceof Error ? error.message : "Viewer load failed");
      });

    return () => {
      active = false;
    };
  }, []);

  return (
    <main style={styles.page}>
      <header style={styles.header}>
        <div>
          <p style={styles.eyebrow}>Phase 1</p>
          <h1 style={styles.title}>PCB viewer</h1>
          <p style={styles.subtitle}>
            Interactive layers and browser-native review live here. Editing
            stays outside scope until the later EDA engine milestone.
          </p>
        </div>
        <ProductNav />
      </header>

      <section style={styles.grid}>
        <KiCanvasViewer
          boardUrl={project?.boardUrl ?? null}
          schematicUrl={project?.schematicUrl ?? null}
        />
        <article style={styles.panel}>
          <h2 style={styles.panelTitle}>Artifact lane</h2>
          <p style={styles.summary}>{project?.reviewSummary ?? "No artifact metadata yet."}</p>
          <div style={styles.list}>
            {(project?.artifacts ?? []).map((artifact) => (
              <div key={artifact.id} style={styles.card}>
                <strong>{artifact.label}</strong>
                <span>{artifact.kind}</span>
                <span>{artifact.status}</span>
                <code>{artifact.sourcePath ?? "pending artifact path"}</code>
                {artifact.url ? (
                  <a
                    href={artifact.url}
                    style={styles.link}
                    target="_blank"
                    rel="noreferrer"
                  >
                    Open artifact
                  </a>
                ) : (
                  <span style={styles.pending}>Preview route pending</span>
                )}
              </div>
            ))}
          </div>
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
    maxWidth: "60ch"
  },
  grid: {
    display: "grid",
    gridTemplateColumns: "minmax(0, 1.3fr) 360px",
    gap: "20px",
    alignItems: "start"
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
  summary: {
    marginTop: 0,
    marginBottom: "14px",
    color: "#b7c8e3"
  },
  list: {
    display: "grid",
    gap: "10px"
  },
  card: {
    display: "grid",
    gap: "4px",
    padding: "12px 14px",
    borderRadius: "18px",
    background: "rgba(5, 12, 24, 0.76)"
  },
  link: {
    color: "#77f2c9",
    textDecoration: "none"
  },
  pending: {
    color: "#8da6c8"
  },
  footer: {
    color: "#8da6c8",
    fontFamily: "var(--font-mono), monospace"
  }
};
