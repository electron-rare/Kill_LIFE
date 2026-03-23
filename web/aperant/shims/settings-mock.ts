/**
 * Web settings mock — replaces the default browser mock with
 * real API calls to the Aperant Web Backend.
 */

import { DEFAULT_APP_SETTINGS } from '../../../tools/aperant/apps/desktop/src/shared/constants';

const API_BASE = window.location.origin;

// Cache settings in memory after first fetch
let cachedSettings: Record<string, unknown> | null = null;

async function fetchSettings(): Promise<Record<string, unknown>> {
  if (cachedSettings) return cachedSettings;
  try {
    const res = await fetch(`${API_BASE}/api/settings`);
    const json = await res.json();
    if (json.success && json.data) {
      cachedSettings = { ...DEFAULT_APP_SETTINGS, ...json.data };
      return cachedSettings;
    }
  } catch (e) {
    console.warn('[Web API] Failed to fetch settings:', e);
  }
  return { ...DEFAULT_APP_SETTINGS };
}

async function persistSettings(updates: Record<string, unknown>): Promise<void> {
  // Merge with cached
  const current = await fetchSettings();
  const merged = { ...current, ...updates };
  cachedSettings = merged;
  try {
    await fetch(`${API_BASE}/api/settings`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(merged),
    });
  } catch (e) {
    console.warn('[Web API] Failed to save settings:', e);
  }
}

export const settingsMock = {
  getSettings: async () => ({
    success: true,
    data: await fetchSettings(),
  }),

  saveSettings: async (updates: Record<string, unknown>) => {
    await persistSettings(updates);
    return { success: true };
  },

  // Sentry error reporting (no-op in web)
  notifySentryStateChanged: (_enabled: boolean) => {},
  getSentryDsn: async () => '',
  getSentryConfig: async () => ({ dsn: '', tracesSampleRate: 0, profilesSampleRate: 0 }),

  // Spell check
  setSpellCheckLanguages: async () => ({ success: true, data: { success: true } }),

  getCliToolsInfo: async () => ({
    success: true,
    data: {
      python: { found: true, source: 'system-path' as const, message: 'Available via tower' },
      git: { found: true, source: 'system-path' as const, message: 'Available via tower' },
      gh: { found: true, source: 'system-path' as const, message: 'Available via tower' },
      glab: { found: false, source: 'fallback' as const, message: 'Not installed' },
      claude: { found: true, source: 'system-path' as const, message: 'Available via tower' },
    },
  }),

  getClaudeCodeOnboardingStatus: async () => ({
    success: true,
    data: { hasCompletedOnboarding: true },
  }),

  getAppVersion: async () => '0.1.0-web',

  checkAppUpdate: async () => ({ success: true, data: null }),
  downloadAppUpdate: async () => ({ success: true }),
  downloadStableUpdate: async () => ({ success: true }),
  installAppUpdate: () => {},
  getDownloadedAppUpdate: async () => ({ success: true, data: null }),

  onAppUpdateAvailable: () => () => {},
  onAppUpdateDownloaded: () => () => {},
  onAppUpdateProgress: () => () => {},
  onAppUpdateStableDowngrade: () => () => {},
  onAppUpdateReadOnlyVolume: () => () => {},
  onAppUpdateError: () => () => {},
};
