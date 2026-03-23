/**
 * Web browser mock — replaces the default Aperant browser-mock.ts
 * with API-backed implementations for settings, projects, and providers.
 *
 * This file re-exports the original mock but patches getSettings,
 * getProjects, getProviderAccounts, etc. to fetch from our REST API.
 */

import type { ElectronAPI } from '../../../tools/aperant/apps/desktop/src/shared/types';
import {
  taskMock,
  workspaceMock,
  terminalMock,
  claudeProfileMock,
  contextMock,
  integrationMock,
  changelogMock,
  insightsMock,
  infrastructureMock,
} from '../../../tools/aperant/apps/desktop/src/renderer/lib/mocks';
import { settingsMock } from './settings-mock';
import { projectMock } from './project-mock';

const API_BASE = window.location.origin;
const isElectron = typeof window !== 'undefined' && window.electronAPI !== undefined;

// ── Provider accounts from settings API ─────────────────────────
async function fetchSettings(): Promise<Record<string, unknown>> {
  try {
    const res = await fetch(`${API_BASE}/api/settings`);
    const json = await res.json();
    if (json.success && json.data) return json.data;
  } catch {}
  return {};
}

// ── Original mock imports (unchanged parts) ─────────────────────
// We import the rest from the original mocks index, but override
// settings, project, and provider operations.

const browserMockAPI: ElectronAPI = {
  // Project Operations — API-backed
  ...projectMock,

  // Task Operations
  ...taskMock,

  // Workspace Management
  ...workspaceMock,

  // Terminal Operations
  ...terminalMock,

  // Claude Profile Management
  ...claudeProfileMock,

  // Settings — API-backed
  ...settingsMock,

  // Roadmap Operations
  getRoadmap: async () => ({ success: true, data: null }),
  getRoadmapStatus: async () => ({ success: true, data: { isRunning: false } }),
  saveRoadmap: async () => ({ success: true }),
  saveCompetitorAnalysis: async () => ({ success: true }),
  generateRoadmap: () => { console.warn('[Web] generateRoadmap called'); },
  refreshRoadmap: () => { console.warn('[Web] refreshRoadmap called'); },
  updateFeatureStatus: async () => ({ success: true }),
  convertFeatureToSpec: async (projectId: string) => ({
    success: true,
    data: {
      id: `task-${Date.now()}`,
      specId: '',
      projectId,
      title: 'Converted Feature',
      description: 'Feature converted from roadmap',
      status: 'backlog' as const,
      subtasks: [],
      logs: [],
      createdAt: new Date(),
      updatedAt: new Date(),
    },
  }),
  stopRoadmap: async () => ({ success: true }),
  saveRoadmapProgress: async () => ({ success: true }),
  loadRoadmapProgress: async () => ({ success: true, data: null }),
  clearRoadmapProgress: async () => ({ success: true }),
  onRoadmapProgress: () => () => {},
  onRoadmapComplete: () => () => {},
  onRoadmapError: () => () => {},
  onRoadmapStopped: () => () => {},

  // Context Operations
  ...contextMock,

  // Integration Operations
  ...integrationMock,

  // Changelog Operations
  ...changelogMock,

  // Insights Operations
  ...insightsMock,

  // Infrastructure Operations
  ...infrastructureMock,

  // API Profile Management — API-backed
  getAPIProfiles: async () => ({
    success: true,
    data: { profiles: [], activeProfileId: null, version: 1 },
  }),
  saveAPIProfile: async (profile: any) => ({
    success: true,
    data: { id: `profile-${Date.now()}`, ...profile, createdAt: Date.now(), updatedAt: Date.now() },
  }),
  updateAPIProfile: async (profile: any) => ({
    success: true,
    data: { ...profile, updatedAt: Date.now() },
  }),
  deleteAPIProfile: async () => ({ success: true }),
  setActiveAPIProfile: async () => ({ success: true }),
  testConnection: async () => ({
    success: true,
    data: { success: true, message: 'Connection successful' },
  }),
  discoverModels: async () => ({ success: true, data: { models: [] } }),

  // Provider Account management — API-backed (reads from settings)
  getProviderAccounts: async () => {
    const settings = await fetchSettings();
    const accounts = (settings.providerAccounts as any[]) || [];
    return { success: true, data: { accounts } };
  },

  saveProviderAccount: async (account: any) => {
    const settings = await fetchSettings();
    const accounts = ((settings.providerAccounts as any[]) || []).slice();
    const newAccount = {
      id: `acc-${Date.now()}`,
      ...account,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };
    accounts.push(newAccount);
    await fetch(`${API_BASE}/api/settings`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...settings, providerAccounts: accounts }),
    });
    return { success: true, data: newAccount };
  },

  updateProviderAccount: async (_id: string, updates: any) => ({
    success: true,
    data: { id: _id, provider: 'anthropic' as const, name: 'Account', authType: 'api-key' as const, billingModel: 'pay-per-use' as const, createdAt: Date.now(), updatedAt: Date.now(), ...updates },
  }),

  deleteProviderAccount: async () => ({ success: true }),
  setProviderAccountQueueOrder: async () => ({ success: true }),
  setCrossProviderQueueOrder: async () => ({ success: true }),
  saveModelOverrides: async () => ({ success: true }),
  testProviderConnection: async () => ({ success: true, data: { success: true } }),
  checkEnvCredentials: async () => ({ success: true, data: {} }),

  // Codex OAuth
  codexAuthLogin: async () => ({ success: false, error: 'Not available in web mode' }),
  codexAuthStatus: async () => ({ success: true, data: { isAuthenticated: false } }),
  codexAuthLogout: async () => ({ success: true }),

  // GitHub API
  github: {
    getGitHubRepositories: async () => ({ success: true, data: [] }),
    getGitHubIssues: async () => ({ success: true, data: { issues: [], hasMore: false } }),
    getGitHubIssue: async () => ({ success: true, data: null as any }),
    getIssueComments: async () => ({ success: true, data: [] }),
    checkGitHubConnection: async () => ({ success: true, data: { connected: false, repoFullName: undefined, error: undefined } }),
    investigateGitHubIssue: () => {},
    importGitHubIssues: async () => ({ success: true, data: { success: true, imported: 0, failed: 0, issues: [] } }),
    createGitHubRelease: async () => ({ success: true, data: { url: '' } }),
    suggestReleaseVersion: async () => ({ success: true, data: { suggestedVersion: '1.0.0', currentVersion: '0.0.0', bumpType: 'minor' as const, commitCount: 0, reason: 'Initial' } }),
    checkGitHubCli: async () => ({ success: true, data: { installed: false } }),
    checkGitHubAuth: async () => ({ success: true, data: { authenticated: false } }),
    startGitHubAuth: async () => ({ success: true, data: { success: false } }),
    getGitHubToken: async () => ({ success: true, data: { token: '' } }),
    getGitHubUser: async () => ({ success: true, data: { username: '' } }),
    listGitHubUserRepos: async () => ({ success: true, data: { repos: [] } }),
    detectGitHubRepo: async () => ({ success: true, data: '' }),
    getGitHubBranches: async () => ({ success: true, data: [] }),
    createGitHubRepo: async () => ({ success: true, data: { fullName: '', url: '' } }),
    addGitRemote: async () => ({ success: true, data: { remoteUrl: '' } }),
    listGitHubOrgs: async () => ({ success: true, data: { orgs: [] } }),
    onGitHubAuthDeviceCode: () => () => {},
    onGitHubAuthChanged: () => () => {},
    onGitHubInvestigationProgress: () => () => {},
    onGitHubInvestigationComplete: () => () => {},
    onGitHubInvestigationError: () => () => {},
    getAutoFixConfig: async () => null,
    saveAutoFixConfig: async () => true,
    getAutoFixQueue: async () => [],
    checkAutoFixLabels: async () => [],
    checkNewIssues: async () => [],
    startAutoFix: () => {},
    onAutoFixProgress: () => () => {},
    onAutoFixComplete: () => () => {},
    onAutoFixError: () => () => {},
    listPRs: async () => ({ prs: [], hasNextPage: false }),
    listMorePRs: async () => ({ prs: [], hasNextPage: false }),
    getPR: async () => null,
    runPRReview: () => {},
    cancelPRReview: async () => true,
    postPRReview: async () => true,
    postPRComment: async () => true,
    mergePR: async () => true,
    assignPR: async () => true,
    markReviewPosted: async () => true,
    getPRReview: async () => null,
    getPRReviewsBatch: async () => ({}),
    notifyExternalReviewComplete: async () => {},
    deletePRReview: async () => true,
    checkNewCommits: async () => ({ hasNewCommits: false, newCommitCount: 0 }),
    checkMergeReadiness: async () => ({ isDraft: false, mergeable: 'UNKNOWN' as const, isBehind: false, ciStatus: 'none' as const, blockers: [] }),
    updatePRBranch: async () => ({ success: true }),
    runFollowupReview: () => {},
    getPRLogs: async () => null,
    getWorkflowsAwaitingApproval: async () => ({ awaiting_approval: 0, workflow_runs: [], can_approve: false }),
    approveWorkflow: async () => true,
    onPRReviewProgress: () => () => {},
    onPRReviewComplete: () => () => {},
    onPRReviewError: () => () => {},
    onPRReviewStateChange: () => () => {},
    onPRLogsUpdated: () => () => {},
    batchAutoFix: () => {},
    getBatches: async () => [],
    onBatchProgress: () => () => {},
    onBatchComplete: () => () => {},
    onBatchError: () => () => {},
    analyzeIssuesPreview: () => {},
    approveBatches: async () => ({ success: true, batches: [] }),
    onAnalyzePreviewProgress: () => () => {},
    onAnalyzePreviewComplete: () => () => {},
    onAnalyzePreviewError: () => () => {},
    startStatusPolling: async () => true,
    stopStatusPolling: async () => true,
    getPollingMetadata: async () => null,
    onPRStatusUpdate: () => () => {},
  },

  // Queue Routing API
  queue: {
    getRunningTasksByProfile: async () => ({ success: true, data: { byProfile: {}, totalRunning: 0 } }),
    getBestProfileForTask: async () => ({ success: true, data: null }),
    getBestUnifiedAccount: async () => ({ success: true, data: null }),
    assignProfileToTask: async () => ({ success: true }),
    updateTaskSession: async () => ({ success: true }),
    getTaskSession: async () => ({ success: true, data: null }),
    onQueueProfileSwapped: () => () => {},
    onQueueSessionCaptured: () => () => {},
    onQueueBlockedNoProfiles: () => () => {},
  },

  // Claude Code Operations
  checkClaudeCodeVersion: async () => ({
    success: true,
    data: {
      installed: '1.0.0', latest: '1.0.0', isOutdated: false, path: '/usr/local/bin/claude',
      detectionResult: { found: true, version: '1.0.0', path: '/usr/local/bin/claude', source: 'system-path' as const, message: 'Available' },
    },
  }),
  installClaudeCode: async () => ({ success: true, data: { command: 'npm install -g @anthropic-ai/claude-code' } }),
  getClaudeCodeVersions: async () => ({ success: true, data: { versions: ['1.0.0'] } }),
  installClaudeCodeVersion: async (version: string) => ({ success: true, data: { command: `npm install -g @anthropic-ai/claude-code@${version}`, version } }),
  getClaudeCodeInstallations: async () => ({
    success: true,
    data: { installations: [{ path: '/usr/local/bin/claude', version: '1.0.0', source: 'system-path' as const, isActive: true }], activePath: '/usr/local/bin/claude' },
  }),
  setClaudeCodeActivePath: async (cliPath: string) => ({ success: true, data: { path: cliPath } }),

  // Worktree
  checkWorktreeChanges: async () => ({ success: true, data: { hasChanges: false, changedFileCount: 0 } }),
  createTerminalWorktree: async () => ({ success: false, error: 'Not available in web mode' }),
  listTerminalWorktrees: async () => ({ success: true, data: [] }),
  removeTerminalWorktree: async () => ({ success: false, error: 'Not available in web mode' }),
  listOtherWorktrees: async () => ({ success: true, data: [] }),

  // MCP
  checkMcpHealth: async (server: any) => ({
    success: true, data: { serverId: server.id, status: 'unknown' as const, message: 'Web mode', checkedAt: new Date().toISOString() },
  }),
  testMcpConnection: async (server: any) => ({
    success: true, data: { serverId: server.id, success: false, message: 'Web mode' },
  }),

  // Screenshot
  getSources: async () => ({ success: true, data: [] }),
  capture: async () => ({ success: false, error: 'Not available in web mode' }),

  // Debug
  getDebugInfo: async () => ({
    systemInfo: { appVersion: '0.1.0-web', platform: 'web', isPackaged: 'false' },
    recentErrors: [], logsPath: '/web/logs', debugReport: '[Web] Debug report',
  }),
  openLogsFolder: async () => ({ success: false, error: 'Not available in web mode' }),
  copyDebugInfo: async () => ({ success: false, error: 'Not available in web mode' }),
  getRecentErrors: async () => [],
  listLogFiles: async () => [],
};

/**
 * Initialize web mock API
 */
export function initBrowserMock(): void {
  if (!isElectron) {
    console.log('%c[Aperant Web] API-backed mock initialized', 'color: #4CAF50; font-weight: bold;');
    (window as Window & { electronAPI: ElectronAPI }).electronAPI = browserMockAPI;
  }
}

// Auto-initialize
initBrowserMock();
