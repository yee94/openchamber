import * as vscode from 'vscode';
import * as os from 'os';
import { createOpencodeServer } from '@opencode-ai/sdk/server';

const READY_CHECK_TIMEOUT_MS = 30000;

export type ConnectionStatus = 'disconnected' | 'connecting' | 'connected' | 'error';

export type OpenCodeDebugInfo = {
  mode: 'managed' | 'external';
  status: ConnectionStatus;
  lastError?: string;
  workingDirectory: string;
  cliAvailable: boolean;
  cliPath: string | null;
  configuredApiUrl: string | null;
  configuredPort: number | null;
  detectedPort: number | null;
  apiPrefix: string;
  apiPrefixDetected: boolean;
  startCount: number;
  restartCount: number;
  lastStartAt: number | null;
  lastConnectedAt: number | null;
  lastExitCode: number | null;
  serverUrl: string | null;
};

export interface OpenCodeManager {
  start(workdir?: string): Promise<void>;
  stop(): Promise<void>;
  restart(): Promise<void>;
  setWorkingDirectory(path: string): Promise<{ success: boolean; restarted: boolean; path: string }>;
  getStatus(): ConnectionStatus;
  getApiUrl(): string | null;
  getWorkingDirectory(): string;
  getDebugInfo(): OpenCodeDebugInfo;
  onStatusChange(callback: (status: ConnectionStatus, error?: string) => void): vscode.Disposable;
}

function resolvePortFromUrl(url: string): number | null {
  try {
    const parsed = new URL(url);
    return parsed.port ? parseInt(parsed.port, 10) : null;
  } catch {
    return null;
  }
}

function inferApiPrefixFromUrl(url: string): string {
  try {
    const parsed = new URL(url);
    const pathname = parsed.pathname;
    if (pathname === '/' || pathname === '') {
      return '';
    }
    return pathname.endsWith('/') ? pathname.slice(0, -1) : pathname;
  } catch {
    return '';
  }
}

export function createOpenCodeManager(_context: vscode.ExtensionContext): OpenCodeManager {
  // Discard unused parameter - reserved for future use (state persistence, subscriptions)
  void _context;
  let server: { url: string; close: () => void } | null = null;
  let status: ConnectionStatus = 'disconnected';
  let lastError: string | undefined;
  const listeners = new Set<(status: ConnectionStatus, error?: string) => void>();
  let workingDirectory: string = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath || os.homedir();
  let startCount = 0;
  let restartCount = 0;
  let lastStartAt: number | null = null;
  let lastConnectedAt: number | null = null;
  let lastExitCode: number | null = null;

  let detectedPort: number | null = null;
  let apiPrefix: string = '';
  let apiPrefixDetected = false;

  const config = vscode.workspace.getConfiguration('openchamber');
  const configuredApiUrl = config.get<string>('apiUrl') || '';
  const useConfiguredUrl = configuredApiUrl && configuredApiUrl.trim().length > 0;

  let configuredPort: number | null = null;
  if (useConfiguredUrl) {
    try {
      const parsed = new URL(configuredApiUrl);
      if (parsed.port) {
        configuredPort = parseInt(parsed.port, 10);
      }
    } catch {
      // Invalid URL
    }
  }

  const setStatus = (newStatus: ConnectionStatus, error?: string) => {
    if (status !== newStatus || lastError !== error) {
      status = newStatus;
      lastError = error;
      if (newStatus === 'connected') {
        lastConnectedAt = Date.now();
      }
      listeners.forEach(cb => cb(status, error));
    }
  };

  const getApiUrl = (): string | null => {
    if (useConfiguredUrl && configuredApiUrl) {
      return configuredApiUrl.replace(/\/+$/, '');
    }
    if (server?.url) {
      return server.url.replace(/\/+$/, '');
    }
    if (detectedPort) {
      return `http://127.0.0.1:${detectedPort}${apiPrefix}`;
    }
    return null;
  };

  async function start(workdir?: string): Promise<void> {
    startCount += 1;
    lastStartAt = Date.now();

    if (typeof workdir === 'string' && workdir.trim().length > 0) {
      workingDirectory = workdir.trim();
    }

    if (useConfiguredUrl && configuredApiUrl) {
      setStatus('connecting');
      setStatus('connected');
      return;
    }

    setStatus('connecting');

    detectedPort = null;
    apiPrefix = '';
    apiPrefixDetected = false;
    lastExitCode = null;

    try {
      // Let the SDK/OS choose a random available port (port: 0)
      server = await createOpencodeServer({
        hostname: '127.0.0.1',
        port: 0,
        timeout: READY_CHECK_TIMEOUT_MS,
        signal: undefined,
      });

      if (server && server.url) {
        detectedPort = resolvePortFromUrl(server.url);
        apiPrefix = inferApiPrefixFromUrl(server.url);
        apiPrefixDetected = apiPrefix.length > 0;
        setStatus('connected');
      } else {
        throw new Error('Server started but URL is missing');
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      
      // Check for ENOENT or generic spawn failure which implies CLI missing
      if (message.includes('ENOENT') || message.includes('spawn opencode')) {
        setStatus('error', 'OpenCode CLI not found. Install it or ensure it\'s in PATH.');
        vscode.window.showErrorMessage(
          'OpenCode CLI not found. Please install it or ensure it\'s in PATH.',
          'More Info'
        ).then(selection => {
          if (selection === 'More Info') {
            vscode.env.openExternal(vscode.Uri.parse('https://github.com/opencode-ai/opencode'));
          }
        });
      } else {
        setStatus('error', `Failed to start OpenCode: ${message}`);
      }
    }
  }

  async function stop(): Promise<void> {
    if (server) {
      try {
        server.close();
      } catch {
        // Ignore close errors
      }
      server = null;
    }

    detectedPort = null;
    setStatus('disconnected');
  }

  async function restart(): Promise<void> {
    restartCount += 1;
    await stop();
    await new Promise(r => setTimeout(r, 250));
    await start();
  }

  async function setWorkingDirectory(newPath: string): Promise<{ success: boolean; restarted: boolean; path: string }> {
    const target = typeof newPath === 'string' && newPath.trim().length > 0 ? newPath.trim() : workingDirectory;
    if (target === workingDirectory) {
      return { success: true, restarted: false, path: target };
    }

    workingDirectory = target;

    if (useConfiguredUrl && configuredApiUrl) {
      return { success: true, restarted: false, path: target };
    }

    return { success: true, restarted: false, path: target };
  }

  return {
    start,
    stop,
    restart,
    setWorkingDirectory,
    getStatus: () => status,
    getApiUrl,
    getWorkingDirectory: () => workingDirectory,
    getDebugInfo: () => ({
      mode: useConfiguredUrl && configuredApiUrl ? 'external' : 'managed',
      status,
      lastError,
      workingDirectory,
      cliAvailable: status !== 'error' || (lastError ? !lastError.includes('CLI not found') : true), // Infer availability from status
      cliPath: null,
      configuredApiUrl: useConfiguredUrl && configuredApiUrl ? configuredApiUrl.replace(/\/+$/, '') : null,
      configuredPort,
      detectedPort,
      apiPrefix,
      apiPrefixDetected,
      startCount,
      restartCount,
      lastStartAt,
      lastConnectedAt,
      lastExitCode,
      serverUrl: getApiUrl(),
    }),
    onStatusChange(callback) {
      listeners.add(callback);
      callback(status, lastError);
      return new vscode.Disposable(() => listeners.delete(callback));
    },
  };
}
