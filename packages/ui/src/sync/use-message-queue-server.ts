import { useMemo, useSyncExternalStore } from 'react';
import type { MessageQueueScope } from '@/lib/message-queue-server';
import { getMessageQueueServerRuntime, type MessageQueueServerSurface } from './message-queue-server-runtime';
import { editServerQueueItemIntoDraft } from './message-queue-server-edit-bridge';
import { getMessageQueueCutover, type MessageQueueCutover } from './message-queue-cutover';
import { getQueueForScope, useMessageQueueStore, type QueueItem } from '@/stores/messageQueueStore';

export type MessageQueueServerScopeInput = { transportIdentity: string; directory: string; sessionID: string };
export type MessageQueueServerScopeView = {
  capability: ReturnType<MessageQueueServerSurface['getState']>['capability'];
  authority: string | undefined;
  mode: 'legacy' | 'server' | 'frozen';
  importState: ReturnType<MessageQueueServerSurface['getState']>['importState'];
  hydration: ReturnType<MessageQueueServerSurface['getState']>['hydration'];
  scope: MessageQueueScope | undefined;
  items: readonly (MessageQueueScope['items'][number] | QueueItem)[];
  actions: Pick<MessageQueueServerSurface, 'admit' | 'edit' | 'remove' | 'reorder' | 'manualSend' | 'refresh' | 'runShadowImport'> & { editIntoDraft: typeof editServerQueueItemIntoDraft };
};

const EMPTY_ITEMS: readonly MessageQueueScope['items'][number][] = [];

export const useMessageQueueServerScope = (input: MessageQueueServerScopeInput, runtime: MessageQueueServerSurface = getMessageQueueServerRuntime(), cutover: MessageQueueCutover = getMessageQueueCutover()): MessageQueueServerScopeView => {
  const key = `${input.transportIdentity}\u0000${input.directory}\u0000${input.sessionID}`;
  const scopeInput = useMemo(() => ({ transportIdentity: input.transportIdentity, directory: input.directory, sessionID: input.sessionID }), [input.directory, input.sessionID, input.transportIdentity]);
  const localSelector = useMemo(() => (state: ReturnType<typeof useMessageQueueStore.getState>) => getQueueForScope(state, { state: 'bound' as const, ...scopeInput }), [scopeInput]);
  const localItems = useMessageQueueStore(localSelector);
  const source = useMemo(() => {
    let previous: MessageQueueServerScopeView | undefined;
    const getSnapshot = (): MessageQueueServerScopeView => {
      const state = runtime.getState(), scope = runtime.getScope(scopeInput), cutoverState = cutover.getSnapshot();
      const mode = cutoverState.ownership === 'legacy-unsupported' ? 'legacy' : cutoverState.ownership === 'server-active' || cutoverState.ownership === 'server-paused' ? 'server' : 'frozen';
      const items = mode === 'server' ? scope?.items ?? EMPTY_ITEMS : mode === 'frozen' ? localItems : EMPTY_ITEMS;
      if (previous?.capability === state.capability && previous.authority === state.authority && previous.mode === mode && previous.importState === state.importState && previous.hydration === state.hydration && previous.scope === scope && previous.items === items) return previous;
      previous = { capability: state.capability, authority: state.authority, mode, importState: state.importState, hydration: state.hydration, scope, items, actions: { admit: runtime.admit, edit: runtime.edit, remove: runtime.remove, reorder: runtime.reorder, manualSend: runtime.manualSend, refresh: runtime.refresh, runShadowImport: runtime.runShadowImport, editIntoDraft: editServerQueueItemIntoDraft } };
      return previous;
    };
    return { subscribe: (listener: () => void) => { const unsubRuntime = runtime.subscribeScope(scopeInput, listener), unsubCutover = cutover.subscribe(listener); return () => { unsubRuntime(); unsubCutover(); }; }, getSnapshot };
  }, [cutover, key, localItems, runtime, scopeInput]);
  return useSyncExternalStore(source.subscribe, source.getSnapshot, source.getSnapshot);
};
