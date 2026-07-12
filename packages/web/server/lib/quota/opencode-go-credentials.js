import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const credentialsPath = () => path.join(
  process.env.OPENCHAMBER_DATA_DIR
    ? path.resolve(process.env.OPENCHAMBER_DATA_DIR)
    : path.join(os.homedir(), '.config', 'openchamber'),
  'quota',
  'opencode-go.json',
);

export const normalizeOpenCodeGoCredential = (value) => {
  const workspaceId = typeof value?.workspaceId === 'string' ? value.workspaceId.trim() : '';
  let authCookie = typeof value?.authCookie === 'string' ? value.authCookie.trim() : '';
  if (authCookie.startsWith('auth=')) authCookie = authCookie.slice(5).trim();
  if (!workspaceId || !authCookie || /[\r\n]/.test(workspaceId) || /[\r\n]/.test(authCookie)) {
    return null;
  }
  return { workspaceId, authCookie };
};

export const readOpenCodeGoCredential = () => {
  try {
    const parsed = JSON.parse(fs.readFileSync(credentialsPath(), 'utf8'));
    return normalizeOpenCodeGoCredential(parsed);
  } catch (error) {
    if (error?.code !== 'ENOENT') console.warn('Failed to read OpenCode Go credentials');
    return null;
  }
};

export const getOpenCodeGoCredentialStatus = () => {
  const credential = readOpenCodeGoCredential();
  return credential ? { configured: true, workspaceId: credential.workspaceId, authCookieMasked: '••••••••' } : { configured: false };
};

export const writeOpenCodeGoCredential = (value) => {
  const credential = normalizeOpenCodeGoCredential(value);
  if (!credential) throw new Error('Workspace ID and auth cookie are required');
  const target = credentialsPath();
  const directory = path.dirname(target);
  const temporary = `${target}.${process.pid}.${Date.now()}.tmp`;
  fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
  try {
    fs.writeFileSync(temporary, `${JSON.stringify(credential, null, 2)}\n`, { mode: 0o600 });
    fs.chmodSync(temporary, 0o600);
    fs.renameSync(temporary, target);
    fs.chmodSync(target, 0o600);
  } finally {
    try { fs.unlinkSync(temporary); } catch {}
  }
  return getOpenCodeGoCredentialStatus();
};

export const deleteOpenCodeGoCredential = () => {
  try { fs.unlinkSync(credentialsPath()); } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
  }
};
