/**
 * Web mock data — fetches real projects from Aperant Web Backend
 * instead of hardcoded demo projects.
 */

import { DEFAULT_PROJECT_SETTINGS } from '../../../tools/aperant/apps/desktop/src/shared/constants';

const API_BASE = window.location.origin;

// Real projects fetched from API
let _projects: any[] | null = null;

export async function loadRealProjects(): Promise<any[]> {
  if (_projects) return _projects;
  try {
    const res = await fetch(`${API_BASE}/api/projects`);
    const json = await res.json();
    if (json.success && json.data?.length) {
      _projects = json.data.map((p: any) => ({
        id: p.id,
        name: p.name,
        path: p.path,
        autoBuildPath: `${p.path}/.auto-claude`,
        settings: DEFAULT_PROJECT_SETTINGS,
        createdAt: new Date(p.createdAt),
        updatedAt: new Date(p.createdAt),
      }));
      return _projects;
    }
  } catch (e) {
    console.warn('[Web API] Failed to load projects:', e);
  }
  return [];
}

// Synchronous export for initial import (populated on first getProjects call)
export const mockProjects = [
  {
    id: '7c10c5a6-0aef-4a79-bb6c-df018a6c34ef',
    name: 'Kill_LIFE',
    path: '/home/clems/Kill_LIFE',
    autoBuildPath: '/home/clems/Kill_LIFE/.auto-claude',
    settings: DEFAULT_PROJECT_SETTINGS,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    id: '1f15c95b-eda5-47bc-b7ef-5f4ba1d4bc9e',
    name: 'Mascarade',
    path: '/home/clems/mascarade',
    autoBuildPath: '/home/clems/mascarade/.auto-claude',
    settings: DEFAULT_PROJECT_SETTINGS,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
];

export const mockInsightsSessions: any[] = [];
export const mockTasks: any[] = [];
