"use client";

type ProjectNode = {
  path: string;
  kind: string;
};

type Props = {
  nodes: ProjectNode[];
  activePath: string | null;
  onSelectPath: (path: string) => void;
};

export function ProjectTree({ nodes, activePath, onSelectPath }: Props) {
  return (
    <div style={styles.root}>
      {nodes.map((node) => {
        const active = activePath === node.path;
        const selectable = node.path.endsWith(".excalidraw");

        return (
          <button
            disabled={!selectable}
            key={node.path}
            onClick={() => onSelectPath(node.path)}
            style={{
              ...styles.item,
              ...(active ? styles.itemActive : null),
              ...(selectable ? null : styles.itemMuted)
            }}
            type="button"
          >
            <span style={styles.kind}>{node.kind}</span>
            <span>{node.path}</span>
          </button>
        );
      })}
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  root: {
    display: "grid",
    gap: "8px"
  },
  item: {
    textAlign: "left",
    background: "rgba(5, 12, 24, 0.76)",
    color: "#edf4ff",
    border: "1px solid rgba(149, 188, 255, 0.12)",
    borderRadius: "16px",
    padding: "12px 14px",
    display: "grid",
    gap: "4px",
    cursor: "pointer"
  },
  itemActive: {
    border: "1px solid rgba(119, 242, 201, 0.4)",
    boxShadow: "inset 0 0 0 1px rgba(119, 242, 201, 0.2)"
  },
  itemMuted: {
    opacity: 0.7,
    cursor: "default"
  },
  kind: {
    color: "#8da6c8",
    fontSize: "0.75rem",
    textTransform: "uppercase",
    letterSpacing: "0.12em"
  }
};
