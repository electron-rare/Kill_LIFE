"use client";

import { startTransition, useEffect, useState } from "react";

import { ExcalidrawCanvas } from "@/components/excalidraw-canvas";
import { KiCanvasViewer } from "@/components/kicanvas-viewer";
import { ProjectTree } from "@/components/project-tree";
import { ProductNav } from "@/components/product-nav";
import { RealtimeStatus } from "@/components/realtime-status";
import {
  PROJECT_SNAPSHOT_QUERY,
  requestGraphQL,
  type ProjectQueryResult
} from "@/lib/graphql/client";
import type { CiRun, Diagram, ProjectSnapshot } from "@/lib/types";

export function ProjectShell() {
  const [project, setProject] = useState<ProjectSnapshot | null>(null);
  const [selectedDiagramPath, setSelectedDiagramPath] = useState<string | null>(
    null
  );
  const [message, setMessage] = useState<string>("Loading GraphQL project...");
  const [saving, setSaving] = useState(false);

  async function loadProjectSnapshot(successMessage?: string) {
    const data = await requestGraphQL<ProjectQueryResult>(PROJECT_SNAPSHOT_QUERY);

    startTransition(() => {
      setProject(data.project);
      setSelectedDiagramPath((current) => {
        if (current && data.project.diagrams.some((diagram) => diagram.path === current)) {
          return current;
        }

        return data.project.diagrams[0]?.path ?? null;
      });
    });

    setMessage(
      successMessage ?? "GraphQL project snapshot loaded from the local Git read model."
    );
  }

  useEffect(() => {
    let active = true;

    loadProjectSnapshot()
      .then(() => {
        if (!active) {
          return;
        }
      })
      .catch((error) => {
        if (!active) {
          return;
        }

        setMessage(error instanceof Error ? error.message : "Load failed");
      });

    return () => {
      active = false;
    };
  }, []);

  const selectedDiagram =
    project?.diagrams.find((diagram) => diagram.path === selectedDiagramPath) ??
    project?.diagrams[0] ??
    null;

  async function saveDiagram(scene: string) {
    if (!selectedDiagram) {
      return;
    }

    setSaving(true);
    setMessage(`Saving ${selectedDiagram.name} into the Git-backed working tree...`);

    try {
      const data = await requestGraphQL<{ saveDiagram: Diagram }>(
        `
          mutation SaveDiagram($path: String!, $scene: String!) {
            saveDiagram(path: $path, scene: $scene) {
              path
              name
              scene
            }
          }
        `,
        {
          path: selectedDiagram.path,
          scene
        }
      );

      await loadProjectSnapshot(
        `${data.saveDiagram.name} saved as a Git-tracked snapshot on ${project?.repoBranch ?? "the current branch"}.`
      );
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Save failed");
    } finally {
      setSaving(false);
    }
  }

  async function enqueueCi(pipeline: string) {
    setMessage(`Queueing ${pipeline} via the CI orchestrator...`);

    try {
      const data = await requestGraphQL<{ enqueueCi: CiRun }>(
        `
          mutation EnqueueCi($pipeline: String!) {
            enqueueCi(pipeline: $pipeline) {
              id
              pipeline
              status
              queuedAt
            }
          }
        `,
        { pipeline }
      );

      setProject((current) =>
        current
          ? {
              ...current,
              ciRuns: [data.enqueueCi, ...current.ciRuns]
            }
          : current
      );
      setMessage(`${pipeline} queued in the worker lane for ${project?.repoBranch ?? "the current branch"}.`);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Queue failed");
    }
  }

  return (
    <main style={styles.page}>
      <header style={styles.header}>
        <div>
          <p style={styles.eyebrow}>Frontend phase 1</p>
          <h1 style={styles.title}>Diagram editor</h1>
          <p style={styles.subtitle}>
            Excalidraw drives the architecture and wiring lane while JSON stays
            versionable next to KiCad assets.
          </p>
        </div>
        <ProductNav />
      </header>

      <section style={styles.shell}>
        <aside style={styles.sidebar}>
          <div style={styles.panelHeader}>
            <h2 style={styles.panelTitle}>Project UI</h2>
            <span style={styles.panelCaption}>
              {project?.repoBranch
                ? `${project.rootPath} · ${project.repoBranch}@${project.repoHead ?? "head"}`
                : project?.rootPath ?? "web/project"}
            </span>
          </div>
          <ProjectTree
            nodes={project?.tree ?? []}
            activePath={selectedDiagram?.path ?? null}
            onSelectPath={setSelectedDiagramPath}
          />
          <article style={styles.gitPanel}>
            <strong style={styles.gitTitle}>Git review lane</strong>
            <p style={styles.gitSummary}>
              {project?.reviewSummary ?? "Waiting for the Git read model..."}
            </p>
            <div style={styles.gitMeta}>
              <span>{project?.repoAuthor ?? "local-worktree"}</span>
              <span>{project?.repoHead ?? "no-head"}</span>
            </div>
            <div style={styles.changedList}>
              {(project?.changedFiles ?? []).slice(0, 6).map((filePath) => (
                <code key={filePath} style={styles.changedItem}>
                  {filePath}
                </code>
              ))}
              {(project?.changedFiles?.length ?? 0) === 0 ? (
                <span style={styles.cleanState}>No tracked changes under `web/project`.</span>
              ) : null}
            </div>
          </article>
        </aside>

        <section style={styles.centerColumn}>
          <div style={styles.canvasPanel}>
            <div style={styles.panelHeader}>
              <div>
                <h2 style={styles.panelTitle}>Excalidraw canvas</h2>
                <span style={styles.panelCaption}>
                  {selectedDiagram?.path ?? "Select a .excalidraw file"}
                </span>
              </div>
              <button
                onClick={() => enqueueCi("kibot")}
                style={styles.secondaryButton}
                type="button"
              >
                Queue KiBot
              </button>
            </div>
            <ExcalidrawCanvas
              key={selectedDiagram?.path ?? "empty"}
              diagramPath={selectedDiagram?.path ?? null}
              scene={selectedDiagram?.scene ?? null}
              onSave={saveDiagram}
              saving={saving}
            />
          </div>
        </section>

        <aside style={styles.inspector}>
          <div style={styles.panelHeader}>
            <h2 style={styles.panelTitle}>PCB viewer</h2>
            <span style={styles.panelCaption}>KiCanvas embed lane</span>
          </div>
          <KiCanvasViewer
            boardUrl={project?.boardUrl ?? null}
            schematicUrl={project?.schematicUrl ?? null}
          />
          <RealtimeStatus room="yiacad-demo" serverUrl="ws://localhost:1234" />
          <section style={styles.ciPanel}>
            <div style={styles.panelHeader}>
              <h2 style={styles.panelTitle}>CI orchestrator</h2>
              <span style={styles.panelCaption}>KiCad headless + KiBot</span>
            </div>
            <div style={styles.buttonRow}>
              <button
                onClick={() => enqueueCi("kicad-headless")}
                style={styles.primaryButton}
                type="button"
              >
                Queue KiCad headless
              </button>
              <button
                onClick={() => enqueueCi("kibot")}
                style={styles.secondaryButton}
                type="button"
              >
                Queue KiBot
              </button>
            </div>
            <div style={styles.runList}>
              {(project?.ciRuns ?? []).map((run) => (
                <article key={run.id} style={styles.runCard}>
                  <strong>{run.pipeline}</strong>
                  <span>{run.status}</span>
                  <code>{run.queuedAt}</code>
                </article>
              ))}
            </div>
          </section>
        </aside>
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
    textTransform: "uppercase",
    letterSpacing: "0.18em",
    fontSize: "0.75rem",
    color: "#8da6c8"
  },
  title: {
    margin: "8px 0 10px",
    fontSize: "clamp(2rem, 4vw, 3.6rem)",
    lineHeight: 1
  },
  subtitle: {
    margin: 0,
    maxWidth: "70ch",
    color: "#b7c8e3"
  },
  shell: {
    display: "grid",
    gridTemplateColumns: "280px minmax(0, 1fr) 360px",
    gap: "20px",
    minHeight: "72vh"
  },
  sidebar: {
    background: "rgba(12, 22, 39, 0.84)",
    border: "1px solid rgba(149, 188, 255, 0.18)",
    borderRadius: "28px",
    padding: "18px",
    boxShadow: "0 24px 80px rgba(0, 0, 0, 0.35)",
    display: "grid",
    gap: "18px",
    alignContent: "start"
  },
  centerColumn: {
    minWidth: 0
  },
  canvasPanel: {
    background: "rgba(12, 22, 39, 0.84)",
    border: "1px solid rgba(149, 188, 255, 0.18)",
    borderRadius: "28px",
    padding: "18px",
    minHeight: "100%",
    boxShadow: "0 24px 80px rgba(0, 0, 0, 0.35)"
  },
  inspector: {
    display: "grid",
    gap: "16px",
    alignContent: "start"
  },
  panelHeader: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    gap: "16px",
    marginBottom: "14px"
  },
  panelTitle: {
    margin: 0,
    fontSize: "1rem"
  },
  panelCaption: {
    color: "#8da6c8",
    fontSize: "0.82rem"
  },
  ciPanel: {
    background: "rgba(12, 22, 39, 0.84)",
    border: "1px solid rgba(149, 188, 255, 0.18)",
    borderRadius: "24px",
    padding: "18px",
    boxShadow: "0 24px 80px rgba(0, 0, 0, 0.35)"
  },
  gitPanel: {
    display: "grid",
    gap: "10px",
    padding: "16px",
    borderRadius: "20px",
    background: "rgba(5, 12, 24, 0.76)"
  },
  gitTitle: {
    fontSize: "0.95rem"
  },
  gitSummary: {
    margin: 0,
    color: "#b7c8e3"
  },
  gitMeta: {
    display: "flex",
    justifyContent: "space-between",
    gap: "12px",
    color: "#8da6c8",
    fontSize: "0.82rem"
  },
  changedList: {
    display: "grid",
    gap: "6px"
  },
  changedItem: {
    padding: "6px 8px",
    borderRadius: "12px",
    background: "rgba(149, 188, 255, 0.08)",
    color: "#d9ebff",
    overflowX: "auto"
  },
  cleanState: {
    color: "#8da6c8",
    fontSize: "0.9rem"
  },
  buttonRow: {
    display: "flex",
    gap: "10px",
    flexWrap: "wrap"
  },
  primaryButton: {
    border: 0,
    borderRadius: "14px",
    padding: "12px 14px",
    background: "linear-gradient(135deg, #77f2c9, #7ea8ff)",
    color: "#03111f",
    cursor: "pointer",
    fontWeight: 600
  },
  secondaryButton: {
    borderRadius: "14px",
    padding: "12px 14px",
    background: "rgba(8, 16, 29, 0.96)",
    color: "#edf4ff",
    border: "1px solid rgba(149, 188, 255, 0.18)",
    cursor: "pointer"
  },
  runList: {
    display: "grid",
    gap: "10px",
    marginTop: "16px"
  },
  runCard: {
    display: "grid",
    gap: "4px",
    padding: "12px 14px",
    borderRadius: "18px",
    background: "rgba(5, 12, 24, 0.76)",
    border: "1px solid rgba(149, 188, 255, 0.12)"
  },
  footer: {
    color: "#8da6c8",
    fontFamily: "var(--font-mono), monospace",
    fontSize: "0.85rem"
  }
};
