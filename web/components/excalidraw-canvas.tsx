"use client";

import dynamic from "next/dynamic";
import { startTransition, useState } from "react";

const Excalidraw = dynamic(
  async () => {
    const module = await import("@excalidraw/excalidraw");
    return module.Excalidraw;
  },
  { ssr: false }
);

type Props = {
  diagramPath: string | null;
  scene: string | null;
  onSave: (scene: string) => Promise<void>;
  saving: boolean;
};

function parseScene(scene: string | null) {
  if (!scene) {
    return {
      elements: [],
      appState: {
        viewBackgroundColor: "#0b1426"
      }
    };
  }

  try {
    return JSON.parse(scene);
  } catch {
    return {
      elements: [],
      appState: {
        viewBackgroundColor: "#0b1426"
      }
    };
  }
}

export function ExcalidrawCanvas({
  diagramPath,
  scene,
  onSave,
  saving
}: Props) {
  const [draft, setDraft] = useState(scene ?? "");

  return (
    <section style={styles.root}>
      <div style={styles.toolbar}>
        <code style={styles.code}>{diagramPath ?? "project/diagrams/*.excalidraw"}</code>
        <button
          disabled={!diagramPath || saving}
          onClick={() => onSave(draft)}
          style={styles.button}
          type="button"
        >
          {saving ? "Saving..." : "Save to Git"}
        </button>
      </div>
      <div style={styles.canvas}>
        <Excalidraw
          initialData={parseScene(scene)}
          onChange={(elements, appState, files) => {
            const nextScene = JSON.stringify(
              {
                type: "excalidraw",
                version: 2,
                source: "yiacad-web",
                elements,
                appState,
                files
              },
              null,
              2
            );

            startTransition(() => {
              setDraft(nextScene);
            });
          }}
          theme="dark"
        />
      </div>
    </section>
  );
}

const styles: Record<string, React.CSSProperties> = {
  root: {
    display: "grid",
    gap: "12px",
    minHeight: "70vh"
  },
  toolbar: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    gap: "12px"
  },
  code: {
    padding: "8px 10px",
    borderRadius: "12px",
    background: "rgba(5, 12, 24, 0.76)",
    color: "#8da6c8"
  },
  button: {
    border: 0,
    borderRadius: "14px",
    padding: "12px 16px",
    background: "linear-gradient(135deg, #77f2c9, #7ea8ff)",
    color: "#03111f",
    cursor: "pointer",
    fontWeight: 600
  },
  canvas: {
    minHeight: "64vh",
    overflow: "hidden",
    borderRadius: "22px",
    border: "1px solid rgba(149, 188, 255, 0.16)",
    background: "rgba(5, 12, 24, 0.76)"
  }
};
