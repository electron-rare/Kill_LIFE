/**
 * Web project mock — fetches real projects from Aperant Web Backend.
 */

import { DEFAULT_PROJECT_SETTINGS } from '../../../tools/aperant/apps/desktop/src/shared/constants';
import { mockProjects, loadRealProjects } from './mock-data';

const API_BASE = window.location.origin;

export const projectMock = {
  addProject: async (projectPath: string) => {
    const name = projectPath.split('/').pop() || 'new-project';
    const res = await fetch(`${API_BASE}/api/projects`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, path: projectPath }),
    });
    const json = await res.json();
    return {
      success: true,
      data: {
        id: json.data?.id ?? `web-${Date.now()}`,
        name,
        path: projectPath,
        autoBuildPath: `${projectPath}/.auto-claude`,
        settings: DEFAULT_PROJECT_SETTINGS,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    };
  },

  removeProject: async () => ({ success: true }),

  getProjects: async () => {
    const projects = await loadRealProjects();
    return {
      success: true,
      data: projects.length ? projects : mockProjects,
    };
  },

  updateProjectSettings: async () => ({ success: true }),

  initializeProject: async () => ({
    success: true,
    data: { success: true, version: '1.0.0', wasUpdate: false },
  }),

  checkProjectVersion: async () => ({
    success: true,
    data: {
      isInitialized: true,
      currentVersion: '1.0.0',
      sourceVersion: '1.0.0',
      updateAvailable: false,
    },
  }),

  getTabState: async () => ({
    success: true,
    data: {
      openProjectIds: ['7c10c5a6-0aef-4a79-bb6c-df018a6c34ef', '1f15c95b-eda5-47bc-b7ef-5f4ba1d4bc9e'],
      activeProjectId: '7c10c5a6-0aef-4a79-bb6c-df018a6c34ef',
      tabOrder: ['7c10c5a6-0aef-4a79-bb6c-df018a6c34ef', '1f15c95b-eda5-47bc-b7ef-5f4ba1d4bc9e'],
    },
  }),

  saveTabState: async () => ({ success: true }),

  getKanbanPreferences: async () => ({ success: true, data: null }),
  saveKanbanPreferences: async () => ({ success: true }),

  selectDirectory: async () => {
    return prompt('Enter project path:', '/home/clems/');
  },

  createProjectFolder: async (_location: string, name: string, initGit: boolean) => ({
    success: true,
    data: { path: `/home/clems/${name}`, name, gitInitialized: initGit },
  }),

  getDefaultProjectLocation: async () => '/home/clems',

  listDirectory: async () => ({ success: true, data: [] }),
  readFile: async () => ({ success: true, data: '' }),

  getGitBranches: async () => ({
    success: true,
    data: ['main', 'develop'],
  }),

  getGitBranchesWithInfo: async () => ({
    success: true,
    data: [
      { name: 'main', type: 'local' as const, displayName: 'main', isCurrent: true },
      { name: 'develop', type: 'local' as const, displayName: 'develop', isCurrent: false },
    ],
  }),

  getCurrentGitBranch: async () => ({ success: true, data: 'main' }),
  detectMainBranch: async () => ({ success: true, data: 'main' }),

  checkGitStatus: async () => ({
    success: true,
    data: { isGitRepo: true, hasCommits: true, currentBranch: 'main' },
  }),

  initializeGit: async () => ({ success: true, data: { success: true } }),
};
