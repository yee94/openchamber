import { getRuntimeUrlResolver } from './runtime-url';
import { subscribeRuntimeEndpointChanged } from './runtime-switch';

type ScheduledTaskRanEvent = {
  type: 'scheduled-task-ran';
  projectId: string;
  taskId: string;
  ranAt: number;
  status: 'running' | 'success' | 'error';
  sessionId?: string;
};

type EventStreamReadyEvent = { type: 'event-stream-ready' };
type WorktreeTopologyChangedEvent = {
  type: 'worktree-topology-changed';
  projectDirectory: string;
  directory: string;
  operation: 'added' | 'removed';
  occurredAt: number;
};
/** Session-index SQLite revision tip — clients GET /api/openchamber/session-index. */
type SessionIndexChangedEvent = {
  type: 'session-index-changed';
  revision: number;
  sync?: { active: boolean; enriching: boolean };
  occurredAt: number;
};
/** Message-queue revision tip — clients GET /api/openchamber/message-queue. */
type MessageQueueChangedEvent = {
  type: 'message-queue-changed';
  revision: number;
  occurredAt: number;
};
type OpenChamberEvent =
  | ScheduledTaskRanEvent
  | EventStreamReadyEvent
  | WorktreeTopologyChangedEvent
  | SessionIndexChangedEvent
  | MessageQueueChangedEvent;
type Listener = (event: OpenChamberEvent) => void;

let eventSource: EventSource | null = null;
let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
let heartbeatTimer: ReturnType<typeof setTimeout> | null = null;
let reconnectAttempt = 0;
let runtimeChangeUnsubscribe: (() => void) | null = null;
const listeners = new Set<Listener>();

const MAX_RECONNECT_DELAY_MS = 30_000;
const HEARTBEAT_TIMEOUT_MS = 45_000;

const clearHeartbeatTimer = () => {
  if (!heartbeatTimer) {
    return;
  }
  clearTimeout(heartbeatTimer);
  heartbeatTimer = null;
};

const scheduleReconnect = () => {
  if (reconnectTimer || listeners.size === 0) {
    return;
  }
  const delay = Math.min(1_000 * Math.pow(2, Math.min(reconnectAttempt, 5)), MAX_RECONNECT_DELAY_MS);
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    reconnectAttempt += 1;
    connect();
  }, delay);
};

const cleanupSource = () => {
  clearHeartbeatTimer();
  if (eventSource) {
    eventSource.close();
  }
  eventSource = null;
};

const resetHeartbeatTimer = () => {
  clearHeartbeatTimer();
  if (listeners.size === 0) {
    return;
  }
  heartbeatTimer = setTimeout(() => {
    cleanupSource();
    scheduleReconnect();
  }, HEARTBEAT_TIMEOUT_MS);
};

const parseEnvelope = (raw: string): { type: string; properties: unknown } | null => {
  if (!raw || raw.trim().length === 0) {
    return null;
  }

  try {
    const parsed = JSON.parse(raw);
    const type = typeof parsed?.type === 'string' ? parsed.type : '';
    const properties = parsed?.properties;
    if (!type) {
      return null;
    }
    return { type, properties };
  } catch {
    return null;
  }
};

export const parseOpenchamberEventEnvelope = (envelope: { type: string; properties: unknown }): OpenChamberEvent | null => {
  if (envelope.type === 'openchamber:event-stream-ready') {
    return envelope.properties === undefined || envelope.properties === null || (typeof envelope.properties === 'object' && !Array.isArray(envelope.properties))
      ? { type: 'event-stream-ready' }
      : null;
  }

  if (envelope.type === 'openchamber:heartbeat') {
    return null;
  }

  const parsed = envelope.properties && typeof envelope.properties === 'object' && !Array.isArray(envelope.properties)
    ? envelope.properties as Record<string, unknown>
    : null;

  if (envelope.type === 'openchamber:worktree-topology-changed') {
    const projectDirectory = typeof parsed?.projectDirectory === 'string' ? parsed.projectDirectory.trim() : '';
    const directory = typeof parsed?.directory === 'string' ? parsed.directory.trim() : '';
    const operation = parsed?.operation;
    const occurredAt = parsed?.occurredAt;
    if (!projectDirectory || !directory || (operation !== 'added' && operation !== 'removed') || typeof occurredAt !== 'number' || !Number.isFinite(occurredAt)) return null;
    return { type: 'worktree-topology-changed', projectDirectory, directory, operation, occurredAt };
  }

  if (envelope.type === 'openchamber:session-index-changed') {
    const revision = parsed?.revision;
    const occurredAt = parsed?.occurredAt;
    if (typeof revision !== 'number' || !Number.isFinite(revision) || revision < 0) return null;
    if (typeof occurredAt !== 'number' || !Number.isFinite(occurredAt)) return null;
    const syncRaw = parsed?.sync && typeof parsed.sync === 'object' && !Array.isArray(parsed.sync)
      ? parsed.sync as Record<string, unknown>
      : null;
    return {
      type: 'session-index-changed',
      revision,
      occurredAt,
      ...(syncRaw
        ? {
            sync: {
              active: syncRaw.active === true,
              enriching: syncRaw.enriching === true,
            },
          }
        : {}),
    };
  }

  if (envelope.type === 'openchamber:message-queue-changed') {
    const revision = parsed?.revision;
    const occurredAt = parsed?.occurredAt;
    if (typeof revision !== 'number' || !Number.isFinite(revision) || revision < 0) return null;
    if (typeof occurredAt !== 'number' || !Number.isFinite(occurredAt)) return null;
    return { type: 'message-queue-changed', revision, occurredAt };
  }

  if (envelope.type !== 'openchamber:scheduled-task-ran') {
    return null;
  }

  const projectId = typeof parsed?.projectId === 'string' ? parsed.projectId : '';
  const taskId = typeof parsed?.taskId === 'string' ? parsed.taskId : '';
  const ranAt = typeof parsed?.ranAt === 'number' ? parsed.ranAt : Date.now();
  const rawStatus = parsed?.status;
  const status = rawStatus === 'running' || rawStatus === 'error' ? rawStatus : 'success';
  if (!projectId || !taskId) {
    return null;
  }

  const nextEvent: ScheduledTaskRanEvent = {
    type: 'scheduled-task-ran',
    projectId,
    taskId,
    ranAt,
    status,
    ...(typeof parsed?.sessionId === 'string' && parsed.sessionId.length > 0 ? { sessionId: parsed.sessionId } : {}),
  };
  return nextEvent;
};

const dispatchFromEnvelope = (envelope: { type: string; properties: unknown }) => {
  const nextEvent = parseOpenchamberEventEnvelope(envelope);
  if (!nextEvent) return;
  if (nextEvent.type === 'event-stream-ready') reconnectAttempt = 0;
  for (const listener of listeners) listener(nextEvent);
};

const connect = () => {
  if (typeof window === 'undefined' || listeners.size === 0) {
    return;
  }
  if (typeof EventSource !== 'function') {
    return;
  }

  if (eventSource && eventSource.readyState !== EventSource.CLOSED) {
    return;
  }

  cleanupSource();

  const source = new EventSource(getRuntimeUrlResolver().sse('/api/openchamber/events'));
  source.onopen = () => {
    if (eventSource !== source) return;
    resetHeartbeatTimer();
  };
  source.onmessage = (event) => {
    if (eventSource !== source) return;
    resetHeartbeatTimer();
    const envelope = parseEnvelope(event.data);
    if (!envelope) {
      return;
    }
    dispatchFromEnvelope(envelope);
  };

  source.onerror = () => {
    if (eventSource !== source) return;
    cleanupSource();
    scheduleReconnect();
  };

  eventSource = source;
};

const ensureRuntimeChangeSubscription = () => {
  if (runtimeChangeUnsubscribe || typeof window === 'undefined') return;
  runtimeChangeUnsubscribe = subscribeRuntimeEndpointChanged(() => {
    cleanupSource();
    reconnectAttempt = 0;
    connect();
  });
};

const cleanupRuntimeChangeSubscription = () => {
  runtimeChangeUnsubscribe?.();
  runtimeChangeUnsubscribe = null;
};

export const subscribeOpenchamberEvents = (listener: Listener): (() => void) => {
  listeners.add(listener);
  ensureRuntimeChangeSubscription();
  connect();

  return () => {
    listeners.delete(listener);
    if (listeners.size === 0) {
      if (reconnectTimer) {
        clearTimeout(reconnectTimer);
        reconnectTimer = null;
      }
      reconnectAttempt = 0;
      cleanupSource();
      cleanupRuntimeChangeSubscription();
    }
  };
};
