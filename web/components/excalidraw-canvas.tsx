"use client";

import dynamic from "next/dynamic";
import { startTransition, useEffect, useRef, useState } from "react";
import { useYjsExcalidraw } from "@/lib/use-yjs-excalidraw";
import type { ExcalidrawImperativeAPI } from "@excalidraw/excalidraw/types/types";

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

/**
 * Derive a stable room name from the diagram path so all users editing the
 * same file end up in the same Yjs room.
 */
function roomNameFor(diagramPath: string | null): string {
  return diagramPath ? `excalidraw:${diagramPath}` : "excalidraw:default";
}

export function ExcalidrawCanvas({
  diagramPath,
  scene,
  onSave,
  saving
}: Props) {
  const [draft, setDraft] = useState(scene ?? "");
  const apiRef = useRef<ExcalidrawImperativeAPI | null>(null);

  const room = roomNameFor(diagramPath);
  const { connected, remoteElements, remoteVersion, pushElements } =
    useYjsExcalidraw(room);

  // Apply remote element updates coming from other peers.
  useEffect(() => {
    if (!remoteElements || !apiRef.current) return;
    apiRef.current.updateScene({ elements: remoteElements });
  }, [remoteVersion]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <section style={styles.root}>
      <div style={styles.toolbar}>
        <code style={styles.code}>
          {diagramPath ?? "project/diagrams/*.excalidraw"}
        </code>
        <span style={styles.status}>
          {connected ? "\u25CF live" : "\u25CB offline"}
        </span>
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
          excalidrawAPI={(api) => {
            apiRef.current = api;
          }}
          initialData={parseScene(scene)}
          onChange={(elements, appState, files) => {
            // Push local changes to Yjs for real-time sync.
            pushElements(elements);

            // Keep local draft for the manual "Save to Git" snapshot.
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
  status: {
    fontSize: "13px",
    color: "#8da6c8",
    marginRight: "auto"
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
