/**
 * Aperant Web Backend
 * Express server with WebSocket PTY terminals + REST API
 * Replaces Electron main process IPC for web deployment.
 *
 * Target: aperant.saillant.cc
 */

import express from 'express';
import cors from 'cors';
import { createServer } from 'node:http';
import { WebSocketServer, WebSocket } from 'ws';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync, readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const PORT = Number(process.env.PORT ?? 5181);
const APP_DIR = process.env.APERANT_APP_DIR ?? resolve(__dirname, '..');
const DATA_DIR = resolve(APP_DIR, '.data');

// Ensure data directory
if (!existsSync(DATA_DIR)) mkdirSync(DATA_DIR, { recursive: true });

// ── Express app ─────────────────────────────────────────────────
const app = express();
app.use(cors());
app.use(express.json());

// Health check
app.get('/api/health', (_req, res) => {
  res.json({ ok: true, version: '0.1.0', host: 'aperant.saillant.cc' });
});

// ── Project API ─────────────────────────────────────────────────
const projectsFile = join(DATA_DIR, 'projects.json');

function loadProjects(): Record<string, unknown>[] {
  if (!existsSync(projectsFile)) return [];
  return JSON.parse(readFileSync(projectsFile, 'utf-8'));
}

function saveProjects(projects: Record<string, unknown>[]) {
  writeFileSync(projectsFile, JSON.stringify(projects, null, 2));
}

app.get('/api/projects', (_req, res) => {
  res.json({ success: true, data: loadProjects() });
});

app.post('/api/projects', (req, res) => {
  const projects = loadProjects();
  const project = { id: randomUUID(), ...req.body, createdAt: new Date().toISOString() };
  projects.push(project);
  saveProjects(projects);
  res.json({ success: true, data: project });
});

// ── Settings API ────────────────────────────────────────────────
const settingsFile = join(DATA_DIR, 'settings.json');

app.get('/api/settings', (_req, res) => {
  if (!existsSync(settingsFile)) return res.json({ success: true, data: {} });
  res.json({ success: true, data: JSON.parse(readFileSync(settingsFile, 'utf-8')) });
});

app.put('/api/settings', (req, res) => {
  writeFileSync(settingsFile, JSON.stringify(req.body, null, 2));
  res.json({ success: true });
});

// ── Tasks / Specs API ───────────────────────────────────────────
const tasksDir = join(DATA_DIR, 'tasks');
if (!existsSync(tasksDir)) mkdirSync(tasksDir, { recursive: true });

app.get('/api/tasks/:projectId', (req, res) => {
  const file = join(tasksDir, `${req.params.projectId}.json`);
  if (!existsSync(file)) return res.json({ success: true, data: [] });
  res.json({ success: true, data: JSON.parse(readFileSync(file, 'utf-8')) });
});

app.post('/api/tasks/:projectId', (req, res) => {
  const file = join(tasksDir, `${req.params.projectId}.json`);
  const tasks = existsSync(file) ? JSON.parse(readFileSync(file, 'utf-8')) : [];
  const task = { id: randomUUID(), ...req.body, createdAt: new Date().toISOString() };
  tasks.push(task);
  writeFileSync(file, JSON.stringify(tasks, null, 2));
  res.json({ success: true, data: task });
});

// ── Frappe Sync (ops.saillant.cc via tower local port 18100) ────
const FRAPPE_BASE = process.env.FRAPPE_URL ?? 'http://localhost:18100';
const FRAPPE_KEY = process.env.FRAPPE_API_KEY ?? '';
const FRAPPE_SECRET = process.env.FRAPPE_API_SECRET ?? '';

interface FrappeTask {
  name: string;
  subject: string;
  status: string;
  project: string;
  priority: string;
  exp_start_date: string | null;
  exp_end_date: string | null;
  description: string | null;
}

async function fetchFrappeTasks(): Promise<FrappeTask[]> {
  const url = `${FRAPPE_BASE}/api/resource/Task?limit_page_length=200&fields=["name","subject","status","project","priority","exp_start_date","exp_end_date","description"]`;
  const headers: Record<string, string> = { 'Accept': 'application/json' };
  if (FRAPPE_KEY && FRAPPE_SECRET) {
    headers['Authorization'] = `token ${FRAPPE_KEY}:${FRAPPE_SECRET}`;
  }
  try {
    const res = await fetch(url, { headers });
    const json = await res.json() as { data: FrappeTask[] };
    return json.data ?? [];
  } catch (e) {
    console.error('[Frappe] Sync failed:', e);
    return [];
  }
}

const frappeStatusMap: Record<string, string> = {
  'Open': 'backlog',
  'Working': 'in_progress',
  'Pending Review': 'in_progress',
  'Overdue': 'in_progress',
  'Completed': 'done',
  'Cancelled': 'backlog',
};

app.post('/api/frappe/sync', async (_req, res) => {
  const frappeTasks = await fetchFrappeTasks();
  if (!frappeTasks.length) return res.json({ success: false, error: 'No tasks from Frappe or auth failed' });

  const projects = loadProjects();
  const killLifeId = projects.find((p: any) => p.name === 'Kill_LIFE')?.id as string;
  const mascaradeId = projects.find((p: any) => p.name === 'Mascarade')?.id as string;

  const techProjects = new Set(['Kill_LIFE', 'Technique', 'Infrastructure']);
  let synced = 0;

  for (const ft of frappeTasks) {
    const projectId = techProjects.has(ft.project) ? killLifeId : mascaradeId;
    if (!projectId) continue;

    const file = join(tasksDir, `${projectId}.json`);
    const existing = existsSync(file) ? JSON.parse(readFileSync(file, 'utf-8')) : [];

    // Skip if already synced (by frappe name)
    if (existing.some((t: any) => t.frappeId === ft.name)) continue;

    const task = {
      id: randomUUID(),
      frappeId: ft.name,
      title: ft.subject,
      description: ft.description || `[Frappe/${ft.project}] ${ft.subject}`,
      status: frappeStatusMap[ft.status] ?? 'backlog',
      priority: ft.priority,
      project: ft.project,
      startDate: ft.exp_start_date,
      endDate: ft.exp_end_date,
      source: 'frappe-ops',
      createdAt: new Date().toISOString(),
    };
    existing.push(task);
    writeFileSync(file, JSON.stringify(existing, null, 2));
    synced++;
  }

  res.json({ success: true, synced, total: frappeTasks.length });
});

app.post('/api/frappe/sync-bulk', (req, res) => {
  const { tasks: frappeTasks } = req.body;
  if (!frappeTasks?.length) return res.json({ success: false, error: 'No tasks provided' });

  const projects = loadProjects();
  const killLifeId = (projects.find((p: any) => p.name === 'Kill_LIFE') as any)?.id;
  const mascaradeId = (projects.find((p: any) => p.name === 'Mascarade') as any)?.id;
  const techProjects = new Set(['Kill_LIFE', 'Technique', 'Infrastructure', '']);

  let synced = 0;
  for (const ft of frappeTasks) {
    const projectId = techProjects.has(ft.project) ? killLifeId : mascaradeId;
    if (!projectId) continue;

    const file = join(tasksDir, `${projectId}.json`);
    const existing = existsSync(file) ? JSON.parse(readFileSync(file, 'utf-8')) : [];
    if (existing.some((t: any) => t.frappeId === ft.name)) continue;

    existing.push({
      id: randomUUID(),
      frappeId: ft.name,
      title: ft.subject,
      description: ft.description || `[Frappe/${ft.project}] ${ft.subject}`,
      status: frappeStatusMap[ft.status] ?? 'backlog',
      priority: ft.priority,
      project: ft.project,
      startDate: ft.exp_start_date || null,
      endDate: ft.exp_end_date || null,
      source: 'frappe-ops',
      createdAt: new Date().toISOString(),
    });
    writeFileSync(file, JSON.stringify(existing, null, 2));
    synced++;
  }

  res.json({ success: true, synced, total: frappeTasks.length });
});

app.get('/api/frappe/status', async (_req, res) => {
  const frappeTasks = await fetchFrappeTasks();
  res.json({
    success: frappeTasks.length > 0,
    taskCount: frappeTasks.length,
    frappeUrl: FRAPPE_BASE,
    hasAuth: !!(FRAPPE_KEY && FRAPPE_SECRET),
  });
});

// ── Helper: resolve project path ────────────────────────────────
function getProjectPath(projectId: string): string | null {
  const projects = loadProjects();
  const project = projects.find((p: any) => p.id === projectId);
  return (project as any)?.path ?? null;
}

// ── Git / Workspace info (per-project) ──────────────────────────
app.get('/api/projects/:projectId/git/status', (req, res) => {
  const cwd = getProjectPath(req.params.projectId);
  if (!cwd || !existsSync(cwd)) return res.json({ success: false, error: 'Project path not found' });
  const proc = spawn('git', ['status', '--porcelain', '-b'], { cwd });
  let out = '';
  proc.stdout.on('data', (d: Buffer) => { out += d; });
  proc.on('close', () => {
    res.json({ success: true, data: out.trim() });
  });
});

app.get('/api/projects/:projectId/git/log', (req, res) => {
  const cwd = getProjectPath(req.params.projectId);
  if (!cwd || !existsSync(cwd)) return res.json({ success: false, error: 'Project path not found' });
  const count = String(req.query.count ?? '20');
  const proc = spawn('git', ['log', `--max-count=${count}`, '--oneline', '--decorate'], { cwd });
  let out = '';
  proc.stdout.on('data', (d: Buffer) => { out += d; });
  proc.on('close', () => {
    res.json({ success: true, data: out.trim().split('\n') });
  });
});

app.get('/api/projects/:projectId/git/branches', (req, res) => {
  const cwd = getProjectPath(req.params.projectId);
  if (!cwd || !existsSync(cwd)) return res.json({ success: false, error: 'Project path not found' });
  const proc = spawn('git', ['branch', '-a', '--format=%(refname:short)'], { cwd });
  let out = '';
  proc.stdout.on('data', (d: Buffer) => { out += d; });
  proc.on('close', () => {
    res.json({ success: true, data: out.trim().split('\n').filter(Boolean) });
  });
});

app.get('/api/projects/:projectId/git/diff', (req, res) => {
  const cwd = getProjectPath(req.params.projectId);
  if (!cwd || !existsSync(cwd)) return res.json({ success: false, error: 'Project path not found' });
  const proc = spawn('git', ['diff', '--stat'], { cwd });
  let out = '';
  proc.stdout.on('data', (d: Buffer) => { out += d; });
  proc.on('close', () => {
    res.json({ success: true, data: out.trim() });
  });
});

// ── Project file tree ───────────────────────────────────────────
app.get('/api/projects/:projectId/tree', (req, res) => {
  const cwd = getProjectPath(req.params.projectId);
  if (!cwd || !existsSync(cwd)) return res.json({ success: false, error: 'Project path not found' });
  const depth = String(req.query.depth ?? '2');
  const proc = spawn('find', ['.', '-maxdepth', depth, '-not', '-path', './.git/*', '-not', '-path', './node_modules/*'], { cwd });
  let out = '';
  proc.stdout.on('data', (d: Buffer) => { out += d; });
  proc.on('close', () => {
    res.json({ success: true, data: out.trim().split('\n').filter(Boolean).sort() });
  });
});

// ── Legacy git endpoints (default to APP_DIR) ───────────────────
app.get('/api/git/status', (_req, res) => {
  const proc = spawn('git', ['status', '--porcelain', '-b'], { cwd: APP_DIR });
  let out = '';
  proc.stdout.on('data', (d: Buffer) => { out += d; });
  proc.on('close', () => {
    res.json({ success: true, data: out.trim() });
  });
});

app.get('/api/git/log', (req, res) => {
  const count = String(req.query.count ?? '20');
  const proc = spawn('git', ['log', `--max-count=${count}`, '--oneline'], { cwd: APP_DIR });
  let out = '';
  proc.stdout.on('data', (d: Buffer) => { out += d; });
  proc.on('close', () => {
    res.json({ success: true, data: out.trim().split('\n') });
  });
});

// ── Serve static in production ──────────────────────────────────
const distDir = resolve(__dirname, '../dist');
if (existsSync(distDir)) {
  app.use(express.static(distDir));
  app.get('/{*path}', (_req, res) => {
    res.sendFile(join(distDir, 'index.html'));
  });
}

// ── HTTP + WebSocket server ─────────────────────────────────────
const server = createServer(app);

// ── PTY WebSocket terminals ─────────────────────────────────────
const wss = new WebSocketServer({ server, path: '/ws/terminal' });

interface TerminalSession {
  id: string;
  proc: ReturnType<typeof spawn>;
  ws: WebSocket;
}

const terminals = new Map<string, TerminalSession>();

wss.on('connection', (ws, req) => {
  const id = randomUUID();
  const shell = process.env.SHELL ?? '/bin/bash';

  // Extract project ID from query string: /ws/terminal?project=<id>
  const url = new URL(req.url ?? '/', `http://${req.headers.host}`);
  const projectId = url.searchParams.get('project');
  let cwd = APP_DIR;
  if (projectId) {
    const projectPath = getProjectPath(projectId);
    if (projectPath && existsSync(projectPath)) cwd = projectPath;
  }

  // Use child_process.spawn with stdio pipes (cross-platform, no native deps)
  const proc = spawn(shell, ['-i'], {
    cwd,
    env: { ...process.env, TERM: 'xterm-256color' },
    stdio: ['pipe', 'pipe', 'pipe'],
  });

  terminals.set(id, { id, proc, ws });

  // Send terminal ID to client
  ws.send(JSON.stringify({ type: 'init', id }));

  proc.stdout?.on('data', (data: Buffer) => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'output', data: data.toString() }));
    }
  });

  proc.stderr?.on('data', (data: Buffer) => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'output', data: data.toString() }));
    }
  });

  proc.on('exit', (code) => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'exit', code }));
    }
    terminals.delete(id);
  });

  ws.on('message', (raw) => {
    try {
      const msg = JSON.parse(raw.toString());
      if (msg.type === 'input' && proc.stdin?.writable) {
        proc.stdin.write(msg.data);
      } else if (msg.type === 'resize') {
        // resize is handled by PTY; with child_process we skip
      }
    } catch {
      // ignore malformed messages
    }
  });

  ws.on('close', () => {
    proc.kill();
    terminals.delete(id);
  });
});

// ── Start ───────────────────────────────────────────────────────
server.listen(PORT, () => {
  console.log(`\n  Aperant Web Backend`);
  console.log(`  → API:       http://localhost:${PORT}/api/health`);
  console.log(`  → Terminal:  ws://localhost:${PORT}/ws/terminal`);
  console.log(`  → Target:    https://aperant.saillant.cc\n`);
});
