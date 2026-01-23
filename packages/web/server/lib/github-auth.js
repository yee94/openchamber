import fs from 'fs';
import path from 'path';
import os from 'os';

const OPENCHAMBER_DATA_DIR = process.env.OPENCHAMBER_DATA_DIR
  ? path.resolve(process.env.OPENCHAMBER_DATA_DIR)
  : path.join(os.homedir(), '.config', 'openchamber');

const STORAGE_DIR = OPENCHAMBER_DATA_DIR;
const STORAGE_FILE = path.join(STORAGE_DIR, 'github-auth.json');
const SETTINGS_FILE = path.join(OPENCHAMBER_DATA_DIR, 'settings.json');

const DEFAULT_GITHUB_CLIENT_ID = 'Ov23liNd8TxDcMXtAHHM';
const DEFAULT_GITHUB_SCOPES = 'repo read:org workflow read:user user:email';

function ensureStorageDir() {
  if (!fs.existsSync(STORAGE_DIR)) {
    fs.mkdirSync(STORAGE_DIR, { recursive: true });
  }
}

function readJsonFile() {
  ensureStorageDir();
  if (!fs.existsSync(STORAGE_FILE)) {
    return null;
  }
  try {
    const raw = fs.readFileSync(STORAGE_FILE, 'utf8');
    const trimmed = raw.trim();
    if (!trimmed) {
      return null;
    }
    const parsed = JSON.parse(trimmed);
    if (!parsed || typeof parsed !== 'object') {
      return null;
    }
    return parsed;
  } catch (error) {
    console.error('Failed to read GitHub auth file:', error);
    return null;
  }
}

function writeJsonFile(payload) {
  ensureStorageDir();
  fs.writeFileSync(STORAGE_FILE, JSON.stringify(payload, null, 2), 'utf8');
  try {
    fs.chmodSync(STORAGE_FILE, 0o600);
  } catch {
    // best-effort
  }
}

export function getGitHubAuth() {
  const data = readJsonFile();
  if (!data) {
    return null;
  }
  const accessToken = typeof data.accessToken === 'string' ? data.accessToken : '';
  if (!accessToken) {
    return null;
  }
  return {
    accessToken,
    scope: typeof data.scope === 'string' ? data.scope : '',
    tokenType: typeof data.tokenType === 'string' ? data.tokenType : 'bearer',
    createdAt: typeof data.createdAt === 'number' ? data.createdAt : null,
    user: data.user && typeof data.user === 'object'
      ? {
        login: typeof data.user.login === 'string' ? data.user.login : null,
        avatarUrl: typeof data.user.avatarUrl === 'string' ? data.user.avatarUrl : null,
        id: typeof data.user.id === 'number' ? data.user.id : null,
        name: typeof data.user.name === 'string' ? data.user.name : null,
        email: typeof data.user.email === 'string' ? data.user.email : null,
      }
      : null,
  };
}

export function setGitHubAuth({ accessToken, scope, tokenType, user }) {
  if (!accessToken || typeof accessToken !== 'string') {
    throw new Error('accessToken is required');
  }
  writeJsonFile({
    accessToken,
    scope: typeof scope === 'string' ? scope : '',
    tokenType: typeof tokenType === 'string' ? tokenType : 'bearer',
    createdAt: Date.now(),
    user: user && typeof user === 'object'
      ? {
        login: typeof user.login === 'string' ? user.login : undefined,
        avatarUrl: typeof user.avatarUrl === 'string' ? user.avatarUrl : undefined,
        id: typeof user.id === 'number' ? user.id : undefined,
        name: typeof user.name === 'string' ? user.name : undefined,
        email: typeof user.email === 'string' ? user.email : undefined,
      }
      : undefined,
  });
}

export function clearGitHubAuth() {
  try {
    if (fs.existsSync(STORAGE_FILE)) {
      fs.unlinkSync(STORAGE_FILE);
    }
    return true;
  } catch (error) {
    console.error('Failed to clear GitHub auth file:', error);
    return false;
  }
}

export function getGitHubClientId() {
  const raw = process.env.OPENCHAMBER_GITHUB_CLIENT_ID;
  const clientId = typeof raw === 'string' ? raw.trim() : '';
  if (clientId) return clientId;

  try {
    if (fs.existsSync(SETTINGS_FILE)) {
      const parsed = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
      const stored = typeof parsed?.githubClientId === 'string' ? parsed.githubClientId.trim() : '';
      if (stored) return stored;
    }
  } catch {
    // ignore
  }

  return DEFAULT_GITHUB_CLIENT_ID;
}

export function getGitHubScopes() {
  const raw = process.env.OPENCHAMBER_GITHUB_SCOPES;
  const fromEnv = typeof raw === 'string' ? raw.trim() : '';
  if (fromEnv) return fromEnv;

  try {
    if (fs.existsSync(SETTINGS_FILE)) {
      const parsed = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
      const stored = typeof parsed?.githubScopes === 'string' ? parsed.githubScopes.trim() : '';
      if (stored) return stored;
    }
  } catch {
    // ignore
  }

  return DEFAULT_GITHUB_SCOPES;
}

export const GITHUB_AUTH_FILE = STORAGE_FILE;
