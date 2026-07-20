import { admitTextQueueItem, editTextQueueItem, fetchMessageQueueScope, fetchMessageQueueServerStatus, fetchMessageQueueSnapshot, MessageQueueServerError, pauseMessageQueueAuthority, releaseMessageQueueItemEditReservation, removeQueueItem, removeReservedMessageQueueItem, reorderQueueScope, reserveMessageQueueItemForEdit, renewEditReservation, resumeMessageQueueAuthority, sendQueueItemNow, waitForMessageQueueChanges, type MessageQueueAdmissionItem, type MessageQueueEditReservation, type MessageQueueEditReservationRenewal, type MessageQueueItem, type MessageQueueScope, type MessageQueueScopeDescriptor } from '@/lib/message-queue-server';
import { queryClient } from '@/lib/queryRuntime';
import { getRuntimeGeneration, getRuntimeTransportIdentity, subscribeRuntimeEndpointChanged, isRuntimeEndpointIdentityChange } from '@/lib/runtime-switch';
import { clearMessageQueueScope, clearMessageQueueScopes, invalidateMessageQueueScope, readMessageQueueScope, replaceMessageQueueScope, replaceMessageQueueSnapshot, replaceMessageQueueStatus } from '@/queries/messageQueueQueries';
import { uploadQueueAttachments, type QueueAttachmentCandidate } from './message-queue-server-attachment-adapter';
import { getMessageQueueRuntime } from './message-queue-runtime';
import { createMessageQueueShadowImporter, type MessageQueueShadowImportState } from './message-queue-shadow-import';

export type MessageQueueServerCapability = 'idle' | 'available' | 'unsupported' | 'error';
export type MessageQueueServerScopeState = MessageQueueScopeDescriptor;
export type MessageQueueServerSurfaceState = { transportIdentity: string; scopes: ReadonlyMap<string, MessageQueueServerScopeState>; hydration: 'idle' | 'hydrating' | 'ready' | 'error'; capability: MessageQueueServerCapability; authority: string | undefined; isFetching: boolean; error: unknown; importState: MessageQueueShadowImportState };
export type MessageQueueServerRuntimeCapture = { transportIdentity: string; generation: number };
export type MessageQueueServerMutationResult = { status: 'committed' | 'stale'; scope?: MessageQueueScope };
export type MessageQueueServerSurface = { subscribe(listener: () => void): () => void; subscribeScope(scope: { transportIdentity: string; directory: string; sessionID: string }, listener: () => void): () => void; getState(): MessageQueueServerSurfaceState; getScope(scope: { transportIdentity: string; directory: string; sessionID: string }): MessageQueueScope | undefined; captureRuntime(): MessageQueueServerRuntimeCapture; start(): void; stop(): void; restart(): void; runShadowImport(): Promise<MessageQueueShadowImportState>; pause?(expectedGeneration: number): Promise<void>; resume?(expectedGeneration: number): Promise<void>; admit(input: { requestID: string; scope: { directory: string; sessionID: string }; item: Omit<MessageQueueAdmissionItem, 'attachments'>; attachments?: readonly QueueAttachmentCandidate[] }): Promise<MessageQueueServerMutationResult>; edit(input: { requestID: string; scopeID: string; revision: number; item: MessageQueueItem; patch: Parameters<typeof editTextQueueItem>[1]['item'] }): Promise<MessageQueueServerMutationResult>; remove(input: { requestID: string; scopeID: string; revision: number; item: MessageQueueItem }): Promise<MessageQueueServerMutationResult>; reserveEdit(input: { requestID: string; scopeID: string; revision: number; item: MessageQueueItem; owner: string; ttlMs: number; runtime: MessageQueueServerRuntimeCapture }): Promise<MessageQueueEditReservation | undefined>; renewEdit(input: { item: MessageQueueItem; token: string; generation: number; ttlMs: number; runtime: MessageQueueServerRuntimeCapture; signal?: AbortSignal }): Promise<MessageQueueEditReservationRenewal | undefined>; releaseEdit(input: { item: MessageQueueItem; token: string; runtime: MessageQueueServerRuntimeCapture }): Promise<void>; removeReserved(input: { requestID: string; scopeID: string; revision: number; item: MessageQueueItem; token: string; generation: number; runtime: MessageQueueServerRuntimeCapture }): Promise<boolean>; reorder(input: { requestID: string; scopeID: string; revision: number; queueItemIDs: string[] }): Promise<MessageQueueServerMutationResult>; manualSend(input: { requestID: string; scopeID: string; revision: number; item: MessageQueueItem }): Promise<MessageQueueServerMutationResult>; refresh(): Promise<void> };
type Client = Pick<typeof queryClient, 'setQueryData' | 'getQueryData' | 'removeQueries' | 'invalidateQueries'>;
type Dependencies = { snapshot: typeof fetchMessageQueueSnapshot; status: typeof fetchMessageQueueServerStatus; scope: typeof fetchMessageQueueScope; changes: typeof waitForMessageQueueChanges; admit: typeof admitTextQueueItem; edit: typeof editTextQueueItem; remove: typeof removeQueueItem; reserve: typeof reserveMessageQueueItemForEdit; renew: typeof renewEditReservation; release: typeof releaseMessageQueueItemEditReservation; removeReserved: typeof removeReservedMessageQueueItem; reorder: typeof reorderQueueScope; manualSend: typeof sendQueueItemNow; upload: typeof uploadQueueAttachments; client: Client; capture: () => MessageQueueServerRuntimeCapture; current: (capture: MessageQueueServerRuntimeCapture) => boolean; legacyManualSend: (item: MessageQueueItem) => Promise<void>; shadowQueue: () => ReturnType<typeof getMessageQueueRuntime> };
const defaults: Dependencies = { snapshot: fetchMessageQueueSnapshot, status: fetchMessageQueueServerStatus, scope: fetchMessageQueueScope, changes: waitForMessageQueueChanges, admit: admitTextQueueItem, edit: editTextQueueItem, remove: removeQueueItem, reserve: reserveMessageQueueItemForEdit, renew: renewEditReservation, release: releaseMessageQueueItemEditReservation, removeReserved: removeReservedMessageQueueItem, reorder: reorderQueueScope, manualSend: sendQueueItemNow, upload: uploadQueueAttachments, client: queryClient, capture: () => ({ transportIdentity: getRuntimeTransportIdentity(), generation: getRuntimeGeneration() }), current: (capture) => capture.transportIdentity === getRuntimeTransportIdentity() && capture.generation === getRuntimeGeneration(), legacyManualSend: async () => {}, shadowQueue: getMessageQueueRuntime };
const isConflict = (error: unknown) => error instanceof MessageQueueServerError && (error.code === 'revision_conflict' || error.code === 'row_version_conflict');
const scopeKey = (scope: { transportIdentity: string; directory: string; sessionID: string }) => `${scope.transportIdentity}\u0000${scope.directory}\u0000${scope.sessionID}`;
const pause = (ms: number, signal: AbortSignal) => new Promise<void>((resolve) => { const timer = setTimeout(resolve, ms); signal.addEventListener('abort', () => { clearTimeout(timer); resolve(); }, { once: true }); });

export const createMessageQueueServerRuntime = (dependencies: Partial<Dependencies> = {}): MessageQueueServerSurface => {
  const deps = { ...defaults, ...dependencies };
  let state: MessageQueueServerSurfaceState = { transportIdentity: deps.capture().transportIdentity, scopes: new Map(), hydration: 'idle', capability: 'idle', authority: undefined, isFetching: false, error: undefined, importState: { status: 'idle', imported: 0, total: 0, issues: [], canActivate: false } };
  let controller: AbortController | undefined, users = 0, importFlight: Promise<MessageQueueShadowImportState> | undefined;
  const listeners = new Set<() => void>(), scopeListeners = new Map<string, Set<() => void>>();
  const scopeSnapshots = new Map<string, { revision: number; scope: MessageQueueScope }>();
  const publish = (next: Partial<MessageQueueServerSurfaceState>) => { state = { ...state, ...next }; listeners.forEach((listener) => listener()); if (!('scopes' in next)) scopeListeners.forEach((entries) => entries.forEach((listener) => listener())); };
  const isCaptureCurrent = (capture: MessageQueueServerRuntimeCapture) => {
    const current = deps.capture();
    return state.transportIdentity === capture.transportIdentity && current.transportIdentity === capture.transportIdentity && current.generation === capture.generation && deps.current(capture);
  };
  const resetForTransport = (capture: MessageQueueServerRuntimeCapture) => {
    controller?.abort(); controller = undefined; importFlight = undefined; scopeSnapshots.clear();
    publish({ transportIdentity: capture.transportIdentity, scopes: new Map(), hydration: 'idle', capability: 'idle', authority: undefined, isFetching: false, error: undefined, importState: { status: 'idle', imported: 0, total: 0, issues: [], canActivate: false } });
  };
  const synchronizeTransport = () => {
    const capture = deps.capture();
    if (state.transportIdentity !== capture.transportIdentity) resetForTransport(capture);
    return capture;
  };
  const notifyScopes = (previous: ReadonlyMap<string, MessageQueueServerScopeState>, next: ReadonlyMap<string, MessageQueueServerScopeState>, transportIdentity: string) => {
    const keys = new Set([...previous.keys(), ...next.keys()]);
    for (const id of keys) {
      const before = previous.get(id), after = next.get(id);
      if (before?.revision === after?.revision && before?.directory === after?.directory && before?.sessionID === after?.sessionID) continue;
      const key = after ? scopeKey({ transportIdentity, directory: after.directory, sessionID: after.sessionID }) : before ? scopeKey({ transportIdentity, directory: before.directory, sessionID: before.sessionID }) : '';
      scopeListeners.get(key)?.forEach((listener) => listener());
    }
  };
  const setDescriptors = (descriptors: readonly MessageQueueScopeDescriptor[], capture: MessageQueueServerRuntimeCapture) => {
    if (!isCaptureCurrent(capture)) return;
    const previous = state.scopes, next = new Map(descriptors.map((descriptor) => [descriptor.scopeID, descriptor]));
    for (const [key, cached] of scopeSnapshots) if (next.get(cached.scope.scopeID)?.revision !== cached.revision) scopeSnapshots.delete(key);
    publish({ scopes: next }); notifyScopes(previous, next, capture.transportIdentity);
  };
  const loadScope = async (descriptor: MessageQueueScopeDescriptor, capture: MessageQueueServerRuntimeCapture, signal: AbortSignal): Promise<MessageQueueScope> => {
    let offset = 0, expectedRevision: number | undefined, first: MessageQueueScope | undefined;
    const items: MessageQueueItem[] = [];
    do {
      const page = await deps.scope(descriptor.scopeID, { offset, limit: 8, expectedRevision, signal });
      if (!first) first = page;
      if (page.revision !== descriptor.revision || page.scopeID !== descriptor.scopeID || (expectedRevision !== undefined && page.revision !== expectedRevision)) throw new MessageQueueServerError(409, 'revision_conflict');
      items.push(...page.items); expectedRevision = page.revision; offset = page.nextOffset ?? -1;
    } while (offset >= 0);
    if (!first || items.length !== first.itemCount) throw new MessageQueueServerError(200, 'unavailable');
    const complete = { ...first, items };
    if (isCaptureCurrent(capture)) replaceMessageQueueScope(deps.client, complete, capture.transportIdentity);
    return complete;
  };
  const refresh = async () => {
    const capture = synchronizeTransport(), signal = controller?.signal ?? new AbortController().signal;
    publish({ isFetching: true, hydration: 'hydrating', error: undefined });
    try {
      const status = await deps.status(signal); if (!isCaptureCurrent(capture)) return;
      replaceMessageQueueStatus(deps.client, status, capture.transportIdentity);
      publish({ capability: status.capability ? 'available' : 'unsupported', authority: status.authority });
      if (!status.capability) return;
      const snapshot = await deps.snapshot(signal); if (!isCaptureCurrent(capture)) return;
      const prior = state.scopes;
      for (const descriptor of snapshot.scopes) if (prior.get(descriptor.scopeID)?.revision !== descriptor.revision) await loadScope(descriptor, capture, signal);
      if (!isCaptureCurrent(capture)) return;
      replaceMessageQueueSnapshot(deps.client, snapshot, capture.transportIdentity);
      if (snapshot.scopes.length === 0) clearMessageQueueScopes(deps.client, capture.transportIdentity);
      else for (const scopeID of prior.keys()) if (!snapshot.scopes.some((scope) => scope.scopeID === scopeID)) clearMessageQueueScope(deps.client, scopeID, capture.transportIdentity);
      setDescriptors(snapshot.scopes, capture); publish({ hydration: 'ready' });
    } catch (error) { if (!isCaptureCurrent(capture) || signal.aborted) return; publish({ capability: error instanceof MessageQueueServerError && error.status === 501 ? 'unsupported' : 'error', hydration: 'error', error }); }
    finally { if (isCaptureCurrent(capture)) publish({ isFetching: false }); }
  };
  const observe = async () => {
    await refresh(); let revision: number | undefined, failures = 0;
    const observer = controller;
    if (!observer) return;
    const signal = observer.signal;
    while (!signal.aborted && controller === observer) {
      const capture = deps.capture();
      const snapshot = deps.client.getQueryData<Awaited<ReturnType<typeof fetchMessageQueueSnapshot>>>([capture.transportIdentity, 'messageQueue', 'snapshot']);
      revision = snapshot?.revision;
      if (revision === undefined) return;
      try {
        const changes = await deps.changes(revision, { signal, timeoutMs: 25_000 }); if (!isCaptureCurrent(capture) || signal.aborted) return;
        const latest = await deps.snapshot(signal); if (!isCaptureCurrent(capture)) return;
        const known = new Map(state.scopes);
        for (const descriptor of latest.scopes) if (known.get(descriptor.scopeID)?.revision !== descriptor.revision) await loadScope(descriptor, capture, signal);
        if (!isCaptureCurrent(capture)) return;
        replaceMessageQueueSnapshot(deps.client, latest, capture.transportIdentity);
        if (latest.scopes.length === 0) clearMessageQueueScopes(deps.client, capture.transportIdentity);
        else for (const scopeID of known.keys()) if (!latest.scopes.some((scope) => scope.scopeID === scopeID)) clearMessageQueueScope(deps.client, scopeID, capture.transportIdentity);
        setDescriptors(latest.scopes, capture); publish({ hydration: 'ready', error: undefined }); failures = changes.revision >= revision ? 0 : failures;
      } catch (error) { if (signal.aborted || controller !== observer || !isCaptureCurrent(capture)) return; publish({ error, isFetching: false }); await pause(Math.min(30_000, 500 * 2 ** failures++), signal); }
    }
  };
  const applyScope = async (scopeID: string, revision: number, capture: MessageQueueServerRuntimeCapture) => {
    const descriptor = state.scopes.get(scopeID);
    if (!descriptor) return;
    await loadScope({ ...descriptor, revision }, capture, controller?.signal ?? new AbortController().signal);
    if (!isCaptureCurrent(capture)) return;
    const next = new Map(state.scopes); next.set(scopeID, { ...descriptor, revision }); setDescriptors([...next.values()], capture);
  };
  const reloadScope = async (scopeID: string, capture: MessageQueueServerRuntimeCapture, originalError: unknown): Promise<MessageQueueScope | undefined> => {
    const snapshot = await deps.snapshot(controller?.signal); if (!isCaptureCurrent(capture)) return undefined;
    const descriptor = snapshot.scopes.find((entry) => entry.scopeID === scopeID); if (!descriptor) throw originalError;
    const current = await loadScope(descriptor, capture, controller?.signal ?? new AbortController().signal); if (!isCaptureCurrent(capture)) return undefined;
    setDescriptors(snapshot.scopes, capture); replaceMessageQueueSnapshot(deps.client, snapshot, capture.transportIdentity); return current;
  };
  const mutate = async (scopeID: string, revision: number, action: (expectedRevision: number, scope: MessageQueueScope | undefined) => Promise<{ revision: number }>): Promise<MessageQueueServerMutationResult> => {
    const capture = synchronizeTransport(); let expected = revision;
    for (let attempt = 0; attempt < 2; attempt++) {
      const descriptor = state.scopes.get(scopeID); const current = descriptor ? readMessageQueueScope(deps.client, scopeID, descriptor.revision, capture.transportIdentity) : undefined;
      let result: { revision: number };
      try { result = await action(expected, current); }
      catch (error) {
        if (!isConflict(error) || attempt) throw error;
        const reloaded = await reloadScope(scopeID, capture, error); if (!reloaded) return { status: 'stale' };
        expected = reloaded.revision; continue;
      }
      if (!isCaptureCurrent(capture)) return { status: 'stale' };
      try { await applyScope(scopeID, result.revision, capture); }
      catch (error) {
        if (!isConflict(error)) throw error;
        if (!await reloadScope(scopeID, capture, error)) return { status: 'stale' };
      }
      await invalidateMessageQueueScope(deps.client, scopeID, capture.transportIdentity);
      const latest = state.scopes.get(scopeID);
      return { status: 'committed', scope: latest ? readMessageQueueScope(deps.client, scopeID, latest.revision, capture.transportIdentity) : undefined };
    }
    throw new MessageQueueServerError(409, 'revision_conflict');
  };
  const stopObserver = () => { controller?.abort(); controller = undefined; importFlight = undefined; };
  const startObserver = () => { if (controller) return; controller = new AbortController(); void observe(); };
  const runShadowImport = () => {
    if (importFlight) return importFlight;
    const flight = (async () => {
      const capture = synchronizeTransport();
      if (state.capability !== 'available' || state.authority !== 'shadow') { const importState = { status: 'pending', imported: 0, total: 0, issues: ['shadow-unavailable'], canActivate: false } as MessageQueueShadowImportState; publish({ importState }); return importState; }
      return createMessageQueueShadowImporter({ queue: deps.shadowQueue(), capture: () => capture, current: isCaptureCurrent, existing: () => [...state.scopes.values()].flatMap((scope) => readMessageQueueScope(deps.client, scope.scopeID, scope.revision, capture.transportIdentity)?.items ?? []), refresh, publish: (importState) => { if (isCaptureCurrent(capture)) publish({ importState }); } }).run(controller?.signal);
    })();
    const wrapped = flight.finally(() => { if (importFlight === wrapped) importFlight = undefined; }); importFlight = wrapped; return wrapped;
  };
  return {
    subscribe: (listener) => { listeners.add(listener); return () => listeners.delete(listener); },
    subscribeScope: (scope, listener) => { const key = scopeKey(scope), entries = scopeListeners.get(key) ?? new Set(); entries.add(listener); scopeListeners.set(key, entries); return () => { entries.delete(listener); if (!entries.size) scopeListeners.delete(key); }; },
    getState: () => { synchronizeTransport(); return state; }, captureRuntime: () => synchronizeTransport(),
    getScope: (scope) => { const capture = synchronizeTransport(); if (scope.transportIdentity !== capture.transportIdentity || state.transportIdentity !== scope.transportIdentity) return undefined; const descriptor = [...state.scopes.values()].find((entry) => entry.directory === scope.directory && entry.sessionID === scope.sessionID); if (!descriptor) return undefined; const key = `${scope.transportIdentity}\u0000${descriptor.scopeID}`, cached = scopeSnapshots.get(key); if (cached?.revision === descriptor.revision) return cached.scope; const loaded = readMessageQueueScope(deps.client, descriptor.scopeID, descriptor.revision, scope.transportIdentity); if (loaded) scopeSnapshots.set(key, { revision: descriptor.revision, scope: loaded }); return loaded; },
    start: () => { users++; synchronizeTransport(); startObserver(); }, stop: () => { users = Math.max(0, users - 1); if (!users) stopObserver(); }, restart: () => { stopObserver(); resetForTransport(deps.capture()); if (users) startObserver(); }, refresh, runShadowImport,
    pause: async (expectedGeneration) => { await pauseMessageQueueAuthority({ expectedGeneration, signal: controller?.signal }); await refresh(); }, resume: async (expectedGeneration) => { await resumeMessageQueueAuthority({ expectedGeneration, signal: controller?.signal }); await refresh(); },
    admit: async ({ requestID, scope, item, attachments = [] }) => { const capture = synchronizeTransport(), uploaded = await deps.upload(attachments); if (!isCaptureCurrent(capture)) return { status: 'stale' }; await deps.admit({ requestID, scope, item: { ...item, attachments: uploaded.attachments }, signal: controller?.signal }); if (!isCaptureCurrent(capture)) return { status: 'stale' }; await refresh(); return isCaptureCurrent(capture) ? { status: 'committed' } : { status: 'stale' }; },
    edit: ({ requestID, scopeID, revision, item, patch }) => mutate(scopeID, revision, (expected, current) => { const latest = current?.items.find((entry) => entry.queueItemID === item.queueItemID) ?? item; return deps.edit(latest.queueItemID, { requestID, expectedRevision: expected, expectedRowVersion: latest.rowVersion, item: patch, signal: controller?.signal }); }),
    remove: ({ requestID, scopeID, revision, item }) => mutate(scopeID, revision, (expected, current) => { const latest = current?.items.find((entry) => entry.queueItemID === item.queueItemID) ?? item; return deps.remove(latest.queueItemID, { requestID, expectedRevision: expected, expectedRowVersion: latest.rowVersion, signal: controller?.signal }); }),
    reserveEdit: async ({ requestID, scopeID, revision, item, owner, ttlMs, runtime }) => {
      if (!isCaptureCurrent(runtime)) return undefined;
      const current = readMessageQueueScope(deps.client, scopeID, revision, runtime.transportIdentity);
      const latest = current?.items.find((entry) => entry.queueItemID === item.queueItemID);
      if (!latest) return undefined;
      const reserved = await deps.reserve(latest.queueItemID, { requestID, expectedRevision: revision, rowVersion: latest.rowVersion, owner, ttlMs, signal: controller?.signal });
      if (!isCaptureCurrent(runtime)) { await deps.release(latest.queueItemID, { token: reserved.token, signal: controller?.signal }).catch(() => {}); return undefined; }
      return reserved;
    },
    renewEdit: async ({ item, token, generation, ttlMs, runtime, signal }) => {
      if (!isCaptureCurrent(runtime)) return undefined;
      const renewed = await deps.renew(item.queueItemID, { token, generation, ttlMs, signal: signal ?? controller?.signal });
      if (!isCaptureCurrent(runtime) || renewed.queueItemID !== item.queueItemID || renewed.token !== token || renewed.generation !== generation) return undefined;
      return renewed;
    },
    releaseEdit: async ({ item, token, runtime }) => { if (!isCaptureCurrent(runtime)) return; await deps.release(item.queueItemID, { token, signal: controller?.signal.aborted ? undefined : controller?.signal }); if (isCaptureCurrent(runtime)) await refresh(); },
    removeReserved: async ({ requestID, scopeID, revision, item, token, generation, runtime }) => {
      if (!isCaptureCurrent(runtime)) return false;
      const current = readMessageQueueScope(deps.client, scopeID, revision, runtime.transportIdentity);
      const latest = current?.items.find((entry) => entry.queueItemID === item.queueItemID);
      if (!latest) return false;
      const removed = await deps.removeReserved(latest.queueItemID, { requestID, expectedRevision: revision, expectedRowVersion: latest.rowVersion, token, generation, signal: controller?.signal });
      if (!isCaptureCurrent(runtime)) return false;
      await applyScope(scopeID, removed.revision, runtime); await refresh(); return true;
    },
    reorder: ({ requestID, scopeID, revision, queueItemIDs }) => mutate(scopeID, revision, (expected) => deps.reorder(scopeID, { requestID, expectedRevision: expected, queueItemIDs, signal: controller?.signal })),
    manualSend: async ({ requestID, scopeID, revision, item }) => {
      if (state.authority === 'active' || state.authority === 'paused') return mutate(scopeID, revision, (expected, current) => { const latest = current?.items.find((entry) => entry.queueItemID === item.queueItemID) ?? item; return deps.manualSend(latest.queueItemID, { requestID, expectedRevision: expected, expectedRowVersion: latest.rowVersion, signal: controller?.signal }); });
      if (state.authority === 'shadow' || state.capability === 'unsupported') { const capture = synchronizeTransport(); if (!isCaptureCurrent(capture)) return { status: 'stale' }; await deps.legacyManualSend(item); return isCaptureCurrent(capture) ? { status: 'committed' } : { status: 'stale' }; }
      throw new MessageQueueServerError(0, 'unavailable');
    },
  };
};

let defaultRuntime: MessageQueueServerSurface | undefined;
export const getMessageQueueServerRuntime = (): MessageQueueServerSurface => defaultRuntime ??= createMessageQueueServerRuntime();
const switchInstallations = new WeakMap<object, { refs: number; unsubscribe: () => void }>();
export const installMessageQueueServerRuntimeSwitch = (surface: Pick<MessageQueueServerSurface, 'restart'>): (() => void) => {
  const key = surface as object, installed = switchInstallations.get(key);
  if (installed) { installed.refs++; return () => { installed.refs--; if (!installed.refs) { installed.unsubscribe(); switchInstallations.delete(key); } }; }
  const entry = { refs: 1, unsubscribe: subscribeRuntimeEndpointChanged((detail) => { if (isRuntimeEndpointIdentityChange(detail)) surface.restart(); }) };
  switchInstallations.set(key, entry);
  return () => { entry.refs--; if (!entry.refs) { entry.unsubscribe(); switchInstallations.delete(key); } };
};
