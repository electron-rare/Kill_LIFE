"use client";

import { useEffect, useRef, useState } from "react";
import * as Y from "yjs";
import { WebsocketProvider } from "y-websocket";
import type { ExcalidrawElement } from "@excalidraw/excalidraw/types/element/types";

const WS_URL =
  typeof window !== "undefined"
    ? process.env.NEXT_PUBLIC_YJS_WS ?? `ws://${window.location.hostname}:1234`
    : "ws://localhost:1234";

/**
 * Hook that binds an Excalidraw scene to a Yjs shared document.
 *
 * - `roomName` identifies the collaborative room (typically the diagram path).
 * - Returns helpers to read/write elements and a connection status flag.
 */
export function useYjsExcalidraw(roomName: string) {
  const docRef = useRef<Y.Doc | null>(null);
  const providerRef = useRef<WebsocketProvider | null>(null);
  const [connected, setConnected] = useState(false);

  // Shared YArray that holds the serialised element list.
  const yElementsRef = useRef<Y.Array<Record<string, unknown>> | null>(null);

  // Track whether a remote update is being applied so we skip the echo.
  const applyingRemote = useRef(false);

  // Latest remote elements pushed from Yjs observers.
  const [remoteElements, setRemoteElements] = useState<
    ExcalidrawElement[] | null
  >(null);

  // Sequence counter so consumers can detect new remote patches.
  const [remoteVersion, setRemoteVersion] = useState(0);

  useEffect(() => {
    const doc = new Y.Doc();
    const yElements = doc.getArray<Record<string, unknown>>("excalidraw-elements");

    const provider = new WebsocketProvider(WS_URL, roomName, doc);

    docRef.current = doc;
    providerRef.current = provider;
    yElementsRef.current = yElements;

    provider.on("status", ({ status }: { status: string }) => {
      setConnected(status === "connected");
    });

    // When a remote transaction arrives, push the new elements into React state.
    yElements.observe((event) => {
      if (event.transaction.local) return; // ignore our own writes
      applyingRemote.current = true;
      const elements = yElements.toArray() as unknown as ExcalidrawElement[];
      setRemoteElements(elements);
      setRemoteVersion((v) => v + 1);
      // Reset flag after a microtask so the onChange guard can read it.
      queueMicrotask(() => {
        applyingRemote.current = false;
      });
    });

    return () => {
      provider.disconnect();
      provider.destroy();
      doc.destroy();
    };
  }, [roomName]);

  /**
   * Call this from the Excalidraw `onChange` handler.
   * It replaces the entire YArray content with the latest local elements.
   */
  function pushElements(elements: readonly ExcalidrawElement[]) {
    if (applyingRemote.current) return; // skip echo from remote update
    const yElements = yElementsRef.current;
    const doc = docRef.current;
    if (!yElements || !doc) return;

    doc.transact(() => {
      yElements.delete(0, yElements.length);
      // Store plain objects -- Yjs serialises them via its internal encoder.
      yElements.push(elements.map((el) => ({ ...el }) as Record<string, unknown>));
    });
  }

  return { connected, remoteElements, remoteVersion, pushElements };
}
