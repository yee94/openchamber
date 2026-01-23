import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs/promises';

const DEVICE_CODE_URL = 'https://github.com/login/device/code';
const ACCESS_TOKEN_URL = 'https://github.com/login/oauth/access_token';
const API_USER_URL = 'https://api.github.com/user';
const API_EMAILS_URL = 'https://api.github.com/user/emails';
const DEVICE_GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:device_code';

export const DEFAULT_GITHUB_CLIENT_ID = 'Ov23liNd8TxDcMXtAHHM';
export const DEFAULT_GITHUB_SCOPES = 'repo read:org workflow read:user user:email';

type StoredAuth = {
  accessToken: string;
  scope?: string;
  tokenType?: string;
  createdAt?: number;
  user?: { login: string; id?: number; avatarUrl?: string };
};

type JsonRecord = Record<string, unknown>;

type DeviceCodeResponse = {
  device_code: string;
  user_code: string;
  verification_uri: string;
  verification_uri_complete?: string;
  expires_in: number;
  interval: number;
};

type TokenResponse = {
  access_token?: string;
  scope?: string;
  token_type?: string;
  error?: string;
  error_description?: string;
};

const authFilePath = (context: vscode.ExtensionContext) =>
  path.join(context.globalStorageUri.fsPath, 'github-auth.json');

export const readGitHubAuth = async (context: vscode.ExtensionContext): Promise<StoredAuth | null> => {
  try {
    const raw = await fs.readFile(authFilePath(context), 'utf8');
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return null;
    const token = typeof parsed.accessToken === 'string' ? parsed.accessToken : '';
    if (!token) return null;
    return parsed as StoredAuth;
  } catch {
    return null;
  }
};

export const writeGitHubAuth = async (context: vscode.ExtensionContext, auth: StoredAuth): Promise<void> => {
  await fs.mkdir(context.globalStorageUri.fsPath, { recursive: true });
  await fs.writeFile(authFilePath(context), JSON.stringify(auth, null, 2), 'utf8');
  try {
    // best-effort perms on unix
    await fs.chmod(authFilePath(context), 0o600);
  } catch {
    // ignore
  }
};

export const clearGitHubAuth = async (context: vscode.ExtensionContext): Promise<boolean> => {
  try {
    await fs.rm(authFilePath(context));
    return true;
  } catch (err: unknown) {
    if (err && typeof err === 'object' && 'code' in err && (err as { code?: string }).code === 'ENOENT') return true;
    return false;
  }
};

const postForm = async <T extends JsonRecord>(url: string, params: Record<string, string>): Promise<T> => {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Accept: 'application/json',
      'User-Agent': 'OpenChamber',
    },
    body: new URLSearchParams(params).toString(),
  });
  const payload = (await response.json().catch(() => null)) as T | null;
  if (!response.ok) {
    const errorDescription = typeof payload?.error_description === 'string' ? payload.error_description : '';
    const error = typeof payload?.error === 'string' ? payload.error : '';
    throw new Error(errorDescription || error || response.statusText);
  }
  return payload as T;
};

export const startDeviceFlow = async (clientId: string, scope: string) => {
  const payload = await postForm<DeviceCodeResponse>(DEVICE_CODE_URL, { client_id: clientId, scope });
  return {
    deviceCode: payload.device_code,
    userCode: payload.user_code,
    verificationUri: payload.verification_uri,
    verificationUriComplete: payload.verification_uri_complete,
    expiresIn: payload.expires_in,
    interval: payload.interval,
    scope,
  };
};

export const exchangeDeviceCode = async (clientId: string, deviceCode: string) => {
  const payload = await postForm<TokenResponse>(ACCESS_TOKEN_URL, {
    client_id: clientId,
    device_code: deviceCode,
    grant_type: DEVICE_GRANT_TYPE,
  });
  return payload;
};

export const fetchMe = async (accessToken: string) => {
  const response = await fetch(API_USER_URL, {
    method: 'GET',
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${accessToken}`,
      'User-Agent': 'OpenChamber',
    },
  });
  if (response.status === 401) {
    const error = new Error('unauthorized');
    (error as unknown as { status?: number }).status = 401;
    throw error;
  }
  const payload = (await response.json().catch(() => null)) as JsonRecord | null;
  if (!response.ok || !payload) {
    throw new Error(`GitHub /user failed: ${response.statusText}`);
  }

  const name = typeof payload.name === 'string' ? payload.name : undefined;
  let email = typeof payload.email === 'string' ? payload.email : undefined;
  if (!email) {
    try {
      const emailsResponse = await fetch(API_EMAILS_URL, {
        method: 'GET',
        headers: {
          Accept: 'application/vnd.github+json',
          Authorization: `Bearer ${accessToken}`,
          'User-Agent': 'OpenChamber',
        },
      });
      if (emailsResponse.status === 401) {
        const error = new Error('unauthorized');
        (error as unknown as { status?: number }).status = 401;
        throw error;
      }
      const list = (await emailsResponse.json().catch(() => null)) as Array<Record<string, unknown>> | null;
      if (emailsResponse.ok && Array.isArray(list)) {
        const primaryVerified = list.find((e) => Boolean(e?.primary) && Boolean(e?.verified) && typeof e?.email === 'string');
        const anyVerified = list.find((e) => Boolean(e?.verified) && typeof e?.email === 'string');
        email = (primaryVerified?.email as string | undefined) || (anyVerified?.email as string | undefined);
      }
    } catch {
      // ignore
    }
  }

  return {
    login: String(payload.login || ''),
    id: typeof payload.id === 'number' ? payload.id : undefined,
    avatarUrl: typeof payload.avatar_url === 'string' ? payload.avatar_url : undefined,
    name,
    email,
  };
};
