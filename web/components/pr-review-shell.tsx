"use client";

import { useEffect, useState } from "react";

import {
  PROJECT_SNAPSHOT_QUERY,
  requestGraphQL,
  type ProjectQueryResult
} from "@/lib/graphql/client";
import type { ProjectSnapshot } from "@/lib/types";

import { ProductNav } from "@/components/product-nav";

export function PrReviewShell() {
  const [project, setProject] = useState<ProjectSnapshot | null>(null);
  const [message, setMessage] = useState("Loading PR review...");

  useEffect(() => {
    let active = true;

    requestGraphQL<ProjectQueryResult>(PROJECT_SNAPSHOT_QUERY)
      .then((result) => {
        if (!active) {
          return;
        }

        setProject(result.project);
        setMessage("PR review cards loaded from the GraphQL gateway.");
      })
      .catch((error) => {
        if (!active) {
          return;
        }

        setMessage(error instanceof Error ? error.message : "Review load failed");
      });

    return () => {
      active = false;
    };
  }, []);

  return (
    <main style={styles.page}>
      <header style={styles.header}>
        <div>
          <p style={styles.eyebrow}>Killer feature lane</p>
          <h1 style={styles.title}>PR review</h1>
          <p style={styles.subtitle}>
            The review surface combines KiCad diffs, Excalidraw diffs, and
            artifact previews on top of Git-native pull requests.
          </p>
        </div>
        <ProductNav />
      </header>

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
