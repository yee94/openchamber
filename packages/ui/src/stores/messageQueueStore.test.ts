import { beforeEach, describe, expect, test } from 'bun:test';
import { legacyQueueScope, migrateMessageQueueState, queueScopeKey, useMessageQueueStore, type QueueItem, type QueueScope } from './messageQueueStore';

const a: Extract<QueueScope, { state: 'bound' }> = { state: 'bound', transportIdentity: 'runtime-a', directory: '/project', sessionID: 'session-a' };
const b: Extract<QueueScope, { state: 'bound' }> = { ...a, transportIdentity: 'runtime-b' };
const reset = (): void => { useMessageQueueStore.setState({ queuedMessages: {}, followUpBehavior: 'queue' }); };
const add = (scope: QueueScope = a) => useMessageQueueStore.getState().addToQueue(scope, { content: 'message' });

describe('messageQueueStore scoped ledger', () => {
  beforeEach(reset);
  test('uses stable physical scope keys and isolates same session across runtimes', () => {
    const first = add(a); const second = add(b); const state = useMessageQueueStore.getState();
    expect(queueScopeKey(a)).not.toBe(queueScopeKey(b));
    expect(state.getQueueForScope(a)[0]).toBe(first); expect(state.getQueueForScope(b)[0]).toBe(second);
  });
  test('migrates v2 session queues by item owner and remains idempotent', () => {
    const migrated = migrateMessageQueueState({ queuedMessages: { 'session-a': [{ id: 'legacy', content: 'one', createdAt: 1 }, { id: 'owned', content: 'two', createdAt: 2, owner: a }] } });
    const repeated = migrateMessageQueueState(migrated);
    const legacy = migrated.queuedMessages[queueScopeKey(legacyQueueScope('session-a'))]![0] as QueueItem;
    expect(legacy.queueItemID).toBe('legacy'); expect(legacy.owner).toEqual(legacyQueueScope('session-a'));
    expect(repeated.queuedMessages[queueScopeKey(a)]![0]!.operationID).toBe(migrated.queuedMessages[queueScopeKey(a)]![0]!.operationID);
    expect(repeated.queuedMessages[queueScopeKey(a)]![0]!.messageID).toBe(migrated.queuedMessages[queueScopeKey(a)]![0]!.messageID);
  });
  test('locks sending and reconciling items while confirmation still removes the matching identity pair', () => {
    const item = add(); const id = { queueItemID: item.queueItemID, operationID: item.operationID, messageID: item.messageID }; const actions = useMessageQueueStore.getState();
    actions.markQueueItemSendAttempt(a, id); actions.removeFromQueue(a, item.queueItemID, item.operationID); actions.reorderQueue(a, item.queueItemID, item.queueItemID, item.operationID); actions.clearQueue(a);
    expect(actions.getQueueForScope(a)).toHaveLength(1); actions.confirmQueueItem(a, id); expect(actions.getQueueForScope(a)).toEqual([]);
  });
  test('clearAllQueues retains sending and reconciling items', () => {
    const sending = add(a); const reconciling = add(b); const removable = add(a); const actions = useMessageQueueStore.getState();
    actions.markQueueItemSendAttempt(a, sending as Required<Pick<QueueItem, 'queueItemID' | 'operationID' | 'messageID'>>);
    actions.markQueueItemSendAttempt(b, reconciling as Required<Pick<QueueItem, 'queueItemID' | 'operationID' | 'messageID'>>);
    actions.markQueueItemReconciling(b, reconciling as Required<Pick<QueueItem, 'queueItemID' | 'operationID' | 'messageID'>>);
    actions.clearAllQueues();
    expect(actions.getQueueForScope(a)[0]?.status).toBe('sending'); expect(actions.getQueueForScope(b)[0]?.status).toBe('reconciling'); expect(actions.getQueueForScope(a)).toHaveLength(1); expect(actions.getQueueForScope(b)).toHaveLength(1); expect(removable.queueItemID).toBeTruthy();
  });
  test('requires operation and message IDs to identify the same item', () => {
    const first = add(); const second = add(); const actions = useMessageQueueStore.getState();
    actions.confirmQueueItem(a, { operationID: first.operationID, messageID: second.messageID });
    expect(actions.getQueueForScope(a)).toHaveLength(2); actions.confirmQueueItem(a, { operationID: first.operationID, messageID: first.messageID }); expect(actions.getQueueForScope(a)).toHaveLength(1);
  });
  test('keeps unrelated runtime references stable during scoped transitions', () => {
    const first = add(a); const other = add(b); const before = useMessageQueueStore.getState().getQueueForScope(b); useMessageQueueStore.getState().markQueueItemSendAttempt(a, first as Required<Pick<QueueItem, 'queueItemID' | 'operationID' | 'messageID'>>);
    expect(useMessageQueueStore.getState().getQueueForScope(b)).toBe(before); expect(useMessageQueueStore.getState().getQueueForScope(b)[0]).toBe(other);
  });
  test('migrates ownerless v2 ambiguous rows into editable unresolved legacy entries', () => {
    const migrated = migrateMessageQueueState({ queuedMessages: { 'session-a': [{ id: 'sending', content: 'one', createdAt: 1, status: 'sending', reconciliationStartedAt: 10, reconciliationDeadlineAt: 40, reconciliationChecks: 2 }] } });
    const repeated = migrateMessageQueueState(migrated);
    const item = migrated.queuedMessages[queueScopeKey(legacyQueueScope('session-a'))]![0] as QueueItem;
    const again = repeated.queuedMessages[queueScopeKey(legacyQueueScope('session-a'))]![0] as QueueItem;
    expect(item.status).toBe('unresolved'); expect(item.failure?.kind).toBe('ambiguous-dispatch'); expect(item.reconciliationStartedAt).toBe(10); expect(item.reconciliationDeadlineAt).toBe(40); expect(item.reconciliationChecks).toBe(2); expect(again).toEqual(item);
    useMessageQueueStore.setState({ queuedMessages: migrated.queuedMessages }); expect(useMessageQueueStore.getState().popToInput(legacyQueueScope('session-a'), item.queueItemID, item.operationID)?.messageID).toBe(item.messageID);
  });
  test('resolves an exhausted reconciliation into an editable queue item', () => {
    const item = add(); const identity = { queueItemID: item.queueItemID, operationID: item.operationID, messageID: item.messageID }; const actions = useMessageQueueStore.getState();
    actions.markQueueItemSendAttempt(a, identity); actions.markQueueItemReconciling(a, identity);
    actions.recordQueueItemReconciliationCheck(a, identity); actions.recordQueueItemReconciliationCheck(a, identity); actions.recordQueueItemReconciliationCheck(a, identity); actions.resolveQueueItemReconciliation(a, identity);
    expect(actions.getQueueForScope(a)[0]?.status).toBe('unresolved'); expect(actions.popToInput(a, item.queueItemID, item.operationID)?.queueItemID).toBe(item.queueItemID); expect(actions.getQueueForScope(a)).toEqual([]);
  });
  test('resolves a reconciliation when its persisted deadline is reached', () => {
    const item = add(); const identity = { queueItemID: item.queueItemID, operationID: item.operationID, messageID: item.messageID }; const actions = useMessageQueueStore.getState();
    actions.markQueueItemSendAttempt(a, identity); actions.markQueueItemReconciling(a, identity); const reconciling = actions.getQueueForScope(a)[0] as QueueItem;
    const expired = { ...reconciling, reconciliationDeadlineAt: Date.now() - 1 }; useMessageQueueStore.setState({ queuedMessages: { [queueScopeKey(a)]: [expired] } }); actions.resolveQueueItemReconciliation(a, identity);
    expect(actions.getQueueForScope(a)[0]?.status).toBe('unresolved');
  });
  test('resets failed unresolved and retrying heads to a clean queued state for redispatch', () => {
    const item = add(); const identity = { queueItemID: item.queueItemID, operationID: item.operationID, messageID: item.messageID }; const actions = useMessageQueueStore.getState();
    actions.markQueueItemSendAttempt(a, identity); actions.markQueueItemDefinitiveFailure(a, identity);
    actions.resetQueueItemForDispatch(a, identity);
    const reset = actions.getQueueForScope(a)[0] as QueueItem;
    expect(reset.status).toBe('queued');
    expect(reset.nextAttemptAt).toBe(undefined);
    expect(reset.failure).toBe(undefined);
    actions.markQueueItemSendAttempt(a, identity); actions.markQueueItemReconciling(a, identity); actions.resolveQueueItemReconciliation(a, identity);
    actions.resetQueueItemForDispatch(a, identity);
    expect(actions.getQueueForScope(a)[0]?.status).toBe('queued');
    expect(actions.getQueueForScope(a)[0]?.reconciliationDeadlineAt).toBe(undefined);
  });
});
