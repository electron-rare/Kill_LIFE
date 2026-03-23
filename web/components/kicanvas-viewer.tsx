"use client";

import Script from "next/script";
import { useState } from "react";

declare global {
  namespace JSX {
    interface IntrinsicElements {
      "kicanvas-embed": React.DetailedHTMLProps<
        React.HTMLAttributes<HTMLElement>,
        HTMLElement
      > & {
        controls?: string;
        controlslist?: string;
        src?: string;
      };
    }
  }
}

type Props = {
  boardUrl: string | null;
  schematicUrl: string | null;
};

export function KiCanvasViewer({ boardUrl, schematicUrl }: Props) {
  const [ready, setReady] = useState(false);
  const [failed, setFailed] = useState(false);
  const source = boardUrl ?? schematicUrl;

  return (
    <section style={styles.root}>
      <Script
        onError={() => setFailed(true)}
        onReady={() => setReady(true)}
        src="/vendor/kicanvas.js"
        strategy="afterInteractive"
        type="module"
      />
      {!source ? (
        <div style={styles.placeholder}>
          <strong>No KiCad board yet</strong>
          <span>
            Drop a `.kicad_pcb` or `.kicad_sch` file into `web/project/pcb` and
            the GraphQL project service will expose it here.
          </span>
        </div>
      ) : !ready ? (
        <div style={styles.placeholder}>
          <strong>KiCanvas bundle missing</strong>
          <span>
            Add the official `kicanvas.js` bundle to `web/public/vendor` to
            activate the embedded viewer.
          </span>
          {failed ? <code style={styles.code}>/vendor/kicanvas.js failed to load</code> : null}
        </div>
      ) : (
        <div style={styles.viewerFrame}>
          <kicanvas-embed
            controls="full"
            controlslist="nodownload"
            src={source}
            style={styles.embed}
          />
        </div>
      )}
    </section>
  );
}

const styles: Record<string, React.CSSProperties> = {
  root: {
    background: "rgba(12, 22, 39, 0.84)",
    border: "1px solid rgba(149, 188, 255, 0.18)",
    borderRadius: "24px",
    padding: "18px",
    minHeight: "280px",
    boxShadow: "0 24px 80px rgba(0, 0, 0, 0.35)"
  },
  viewerFrame: {
    minHeight: "420px",
    borderRadius: "18px",
    overflow: "hidden",
    background: "rgba(5, 12, 24, 0.76)"
  },
  embed: {
    display: "block",
    width: "100%",
    minHeight: "420px"
  },
  placeholder: {
    display: "grid",
    gap: "8px",
    color: "#b7c8e3"
  },
  code: {
    color: "#ff8e7f"
  }
};
