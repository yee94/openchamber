import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

type OpenCodeGoCredential = { workspaceId: string; authCookie: string };

const targetPath = () => path.join(process.env.OPENCHAMBER_DATA_DIR ? path.resolve(process.env.OPENCHAMBER_DATA_DIR) : path.join(os.homedir(), '.config', 'openchamber'), 'quota', 'opencode-go.json');

export const normalizeOpenCodeGoCredential = (value: unknown): OpenCodeGoCredential | null => {
  if (!value || typeof value !== 'object') return null;
  const data = value as Record<string, unknown>;
  const workspaceId = typeof data.workspaceId === 'string' ? data.workspaceId.trim() : '';
  let authCookie = typeof data.authCookie === 'string' ? data.authCookie.trim() : '';
  if (authCookie.startsWith('auth=')) authCookie = authCookie.slice(5).trim();
  return workspaceId && authCookie && !/[\r\n]/.test(workspaceId + authCookie) ? { workspaceId, authCookie } : null;
};

export const readOpenCodeGoCredential = (): OpenCodeGoCredential | null => {
  try {
    return normalizeOpenCodeGoCredential(JSON.parse(fs.readFileSync(targetPath(), 'utf8')));
  } catch (error) {
    if ((error as { code?: string }).code !== 'ENOENT') {
      console.warn('Failed to read OpenCode Go credentials');
    }
    return null;
  }
};

export const getOpenCodeGoCredentialStatus = () => {
  const value = readOpenCodeGoCredential();
  return value ? { configured: true, workspaceId: value.workspaceId, authCookieMasked: '••••••••' } : { configured: false };
};

export const writeOpenCodeGoCredential = (value: OpenCodeGoCredential) => {
  const target = targetPath();
  const temporary = `${target}.${process.pid}.${Date.now()}.tmp`;
  fs.mkdirSync(path.dirname(target), { recursive: true, mode: 0o700 });
  try {
    fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
    fs.chmodSync(temporary, 0o600);
    fs.renameSync(temporary, target);
    fs.chmodSync(target, 0o600);
  } finally {
    if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
  }
  return getOpenCodeGoCredentialStatus();
};

export const deleteOpenCodeGoCredential = () => { try { fs.unlinkSync(targetPath()); } catch (error) { if ((error as { code?: string }).code !== 'ENOENT') throw error; } };

const toWindow = (usedPercent: number, resetInSec: number) => ({
  usedPercent: Math.min(100, Math.max(0, usedPercent)),
  remainingPercent: 100 - Math.min(100, Math.max(0, usedPercent)),
  windowSeconds: null,
  resetAfterSeconds: Math.max(0, resetInSec),
  resetAt: Date.now() + Math.max(0, resetInSec) * 1000,
  resetAtFormatted: null,
  resetAfterFormatted: null,
});

export const fetchOpenCodeGoUsage = async (credential: OpenCodeGoCredential) => {
  const response = await fetch(`https://opencode.ai/workspace/${encodeURIComponent(credential.workspaceId)}/go`, { headers: { Accept: 'text/html', Cookie: `auth=${credential.authCookie}` }, signal: AbortSignal.timeout(15_000) });
  if (response.status === 401 || response.status === 403 || (response.redirected && /\/auth(?:\/|$|\?)/.test(new URL(response.url).pathname))) throw new Error('OpenCode Go authentication failed');
  if (!response.ok) throw new Error(`OpenCode Go dashboard returned HTTP ${response.status}`);
  const html = (await response.text()).replaceAll('&quot;', '"').replaceAll('&#34;', '"').replaceAll('\\u0022', '"').replaceAll('\\"', '"');
  const windows: Record<string, ReturnType<typeof toWindow>> = {};
  for (const [key, field] of Object.entries({ '5h': 'rollingUsage', weekly: 'weeklyUsage', monthly: 'monthlyUsage' })) {
    const body = html.match(new RegExp(`["']?${field}["']?\\s*:\\s*(?:\\$R\\[\\d+\\]\\s*=\\s*)?\\{([^{}]*)\\}`, 's'))?.[1];
    if (!body) continue;
    const used = Number(body.match(/usagePercent\s*:\s*["']?(-?\d+(?:\.\d+)?)/)?.[1]);
    const reset = Number(body.match(/resetInSec\s*:\s*["']?(-?\d+(?:\.\d+)?)/)?.[1]);
    if (Number.isFinite(used) && Number.isFinite(reset)) windows[key] = toWindow(used, reset);
  }
  if (!Object.keys(windows).length) throw new Error('OpenCode Go usage data could not be parsed');
  return windows;
};
