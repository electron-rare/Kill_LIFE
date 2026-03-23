/**
 * Sentry no-op shim for web build.
 * Replaces @sentry/electron/renderer which is Electron-only.
 */
export function init() {}
export function captureException() {}
export function captureMessage() {}
export function setUser() {}
export function setTag() {}
export function setExtra() {}
export function addBreadcrumb() {}
export function startSpan() {}
export function withScope(cb: (scope: unknown) => void) { cb({}); }
export const browserTracingIntegration = () => ({});
export const replayIntegration = () => ({});
