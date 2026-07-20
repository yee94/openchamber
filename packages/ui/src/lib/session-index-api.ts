import type { Session } from '@opencode-ai/sdk/v2';

import { subscribeOpenchamberEvents } from '@/lib/openchamberEvents';
import { runtimeFetch } from './runtime-fetch';

export type SessionIndexDirectory = {
  directory: string;
  cursor: number | null;
  hasMore: boolean;
  lastSyncedAt: number;
  lastFullSyncedAt: number;
  lastAccessedAt: number;
  sessions: Array<Session & { hasChildren?: boolean }>;
};

export type SessionIndexSnapshot = {
  revision: number;
  sync: {
    active: boolean;
    completed: number;
    total: number;
    pendingDirectories: string[];
    completedDirectories: string[];
    failedDirectories: string[];
    /** Low-priority child-session existence checks still running after root rows are ready. */
    enriching?: boolean;
  };
  directories: SessionIndexDirectory[];
};

const ensureOk = async (response: Response): Promise<void> => {
  if (response.ok) return;
  throw new Error(`session index request failed (${response.status})`);
};

export const loadSessionIndexSnapshot = async (): Promise<SessionIndexSnapshot | null> => {
  if (typeof window === 'undefined') return null;
  const response = await runtimeFetch('/api/openchamber/session-index');
  if (response.status === 501) return null;
  await ensureOk(response);
  const payload = await response.json() as Partial<SessionIndexSnapshot> & { available?: boolean };
  if (payload.available !== true || !Array.isArray(payload.directories)) return null;
  return {
    revision: typeof payload.revision === 'number' ? payload.revision : 0,
    sync: payload.sync ?? {
      active: false,
      completed: 0,
      total: 0,
      pendingDirectories: [],
      completedDirectories: [],
      failedDirectories: [],
      enriching: false,
    },
    directories: payload.directories,
  };
};

export const startSessionIndexBackgroundSync = async (
  directories: string[],
): Promise<SessionIndexSnapshot | null> => {
  if (typeof window === 'undefined') return null;
  const response = await runtimeFetch('/api/openchamber/session-index/sync', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ directories }),
  });
  if (response.status === 501) return null;
  await ensureOk(response);
  return response.json() as Promise<SessionIndexSnapshot>;
};

/**
 * Wait until a session-index tip arrives with revision > afterRevision, or the
 * OpenChamber event stream becomes ready (reconnect repair), or the signal aborts.
 */
export const waitForSessionIndexInvalidation = (
  afterRevision: number,
  signal: AbortSignal,
): Promise<'tip' | 'ready' | 'aborted'> => new Promise((resolve) => {
  if (signal.aborted) {
    resolve('aborted');
    return;
  }
  const finish = (reason: 'tip' | 'ready' | 'aborted') => {
    unsubscribe();
    signal.removeEventListener('abort', onAbort);
    resolve(reason);
  };
  const onAbort = () => finish('aborted');
  const unsubscribe = subscribeOpenchamberEvents((event) => {
    if (event.type === 'event-stream-ready') {
      finish('ready');
      return;
    }
    if (event.type === 'session-index-changed' && event.revision > afterRevision) {
      finish('tip');
    }
  });
  signal.addEventListener('abort', onAbort, { once: true });
});

export const persistSessionIndexDirectory = async (input: {
  directory: string;
  sessions: Session[];
  cursor: number | null;
  hasMore: boolean;
  fullSync?: boolean;
}): Promise<void> => {
  if (typeof window === 'undefined') return;
  const response = await runtimeFetch('/api/openchamber/session-index/directory', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(input),
  });
  if (response.status === 501) return;
  await ensureOk(response);
};

export const persistSessionIndexDirectories = async (directories: Array<{
  directory: string;
  sessions: Session[];
  cursor: number | null;
  hasMore: boolean;
  fullSync?: boolean;
}>): Promise<void> => {
  if (typeof window === 'undefined' || directories.length === 0) return;
  const response = await runtimeFetch('/api/openchamber/session-index/snapshot', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ directories }),
  });
  if (response.status === 501) return;
  await ensureOk(response);
};
