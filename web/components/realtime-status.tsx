"use client";

import { useEffect, useState } from "react";
import { WebsocketProvider } from "y-websocket";
import * as Y from "yjs";

type Props = {
  room: string;
  serverUrl: string;
};

export function RealtimeStatus({ room, serverUrl }: Props) {
  const [status, setStatus] = useState("disconnected");
  const [peers, setPeers] = useState(0);

  useEffect(() => {
    const document = new Y.Doc();
    const provider = new WebsocketProvider(serverUrl, room, document);

    provider.on("status", (event: { status: string }) => {
      setStatus(event.status);
    });

    const updatePeers = () => {
      setPeers(provider.awareness.getStates().size);
    };

    provider.awareness.on("change", updatePeers);
    updatePeers();

    return () => {
      provider.awareness.off("change", updatePeers);
      provider.destroy();
      document.destroy();
    };
  }, [room, serverUrl]);

  return (
    <section style={styles.root}>
      <div style={styles.header}>
        <h2 style={styles.title}>Realtime lane</h2>
        <span style={styles.caption}>Yjs / CRDT transport</span>
      </div>
      <div style={styles.card}>
        <strong>{status}</strong>
        <span>room: {room}</span>
        <span>server: {serverUrl}</span>
        <span>awareness peers: {peers}</span>
        <span>
          Current scaffold exposes the room and transport. Binding Excalidraw
          scene data into CRDT is the next incremental lot.
        </span>
      </div>
    </section>
  );
}

const styles: Record<string, React.CSSProperties> = {
  root: {
    background: "rgba(12, 22, 39, 0.84)",
    border: "1px solid rgba(149, 188, 255, 0.18)",
    borderRadius: "24px",
    padding: "18px",
    boxShadow: "0 24px 80px rgba(0, 0, 0, 0.35)"
  },
  header: {
    display: "flex",
    justifyContent: "space-between",
    gap: "12px",
    marginBottom: "12px"
  },
  title: {
    margin: 0,
    fontSize: "1rem"
  },
  caption: {
    color: "#8da6c8",
    fontSize: "0.82rem"
  },
  card: {
    display: "grid",
    gap: "8px",
    padding: "14px",
    borderRadius: "18px",
    background: "rgba(5, 12, 24, 0.76)"
  }
};
