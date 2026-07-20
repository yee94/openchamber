import { expect, test } from 'bun:test';
import { registerWorktreeOrderWriter, useWorktreeOrderStore } from './useWorktreeOrderStore';

const reset = () => useWorktreeOrderStore.setState({
  runtimeIdentity: 'runtime-a',
  orderByProject: {},
  serverRevisionByProject: {},
  deferredServerOrderByProject: {},
  pendingProjectIDs: {},
  runtimeOrdersByIdentity: { 'runtime-a': { orderByProject: {}, pendingProjectIDs: {} } },
});

test('applies settled remote worktree order and preserves references for equal values', () => {
  reset();
  useWorktreeOrderStore.getState().applyServerWorktreeOrder('project', ['/project/a'], 3);
  const first = useWorktreeOrderStore.getState();
  useWorktreeOrderStore.getState().applyServerWorktreeOrder('project', ['/project/a'], 3);
  const second = useWorktreeOrderStore.getState();
  expect(second.orderByProject).toBe(first.orderByProject);
  expect(second.serverRevisionByProject).toBe(first.serverRevisionByProject);
});

test('keeps optimistic worktree order while recording a remote revision', () => {
  reset();
  useWorktreeOrderStore.getState().markPendingWorktreeOrder('project');
  useWorktreeOrderStore.setState({ orderByProject: { project: ['/project/local'] } });
  useWorktreeOrderStore.getState().applyServerWorktreeOrder('project', ['/project/remote'], 4);
  expect(useWorktreeOrderStore.getState().orderByProject).toEqual({ project: ['/project/local'] });
  expect(useWorktreeOrderStore.getState().serverRevisionByProject).toEqual({ project: 4 });
});

test('keeps the newer authoritative order when an older response arrives', () => {
  reset();
  useWorktreeOrderStore.getState().applyServerWorktreeOrder('project', ['/project/new'], 4);
  useWorktreeOrderStore.getState().applyServerWorktreeOrder('project', ['/project/old'], 3);
  expect(useWorktreeOrderStore.getState().orderByProject).toEqual({ project: ['/project/new'] });
  expect(useWorktreeOrderStore.getState().serverRevisionByProject).toEqual({ project: 4 });
});

test('keeps current authority for equal revisions with different paths', () => {
  reset();
  useWorktreeOrderStore.getState().applyServerWorktreeOrder('project', ['/project/current'], 4);
  useWorktreeOrderStore.getState().applyServerWorktreeOrder('project', ['/project/stale'], 4);
  expect(useWorktreeOrderStore.getState().orderByProject).toEqual({ project: ['/project/current'] });
});

test('resolves pending writes without regressing their observed revision', () => {
  reset();
  useWorktreeOrderStore.setState({ pendingProjectIDs: { project: true }, serverRevisionByProject: { project: 4 } });
  useWorktreeOrderStore.getState().resolvePendingWorktreeOrder('project', 3);
  expect(useWorktreeOrderStore.getState().pendingProjectIDs).toEqual({});
  expect(useWorktreeOrderStore.getState().serverRevisionByProject).toEqual({ project: 4 });
});

test('applies a deferred newer remote order after an older mutation acknowledgement', () => {
  reset();
  useWorktreeOrderStore.setState({ orderByProject: { project: ['/project/local'] }, pendingProjectIDs: { project: true } });
  useWorktreeOrderStore.getState().applyServerWorktreeOrder('project', ['/project/remote'], 10);
  useWorktreeOrderStore.getState().resolvePendingWorktreeOrder('project', 9);
  expect(useWorktreeOrderStore.getState().orderByProject).toEqual({ project: ['/project/remote'] });
  expect(useWorktreeOrderStore.getState().serverRevisionByProject).toEqual({ project: 10 });
  expect(useWorktreeOrderStore.getState().pendingProjectIDs).toEqual({});
  expect(useWorktreeOrderStore.getState().deferredServerOrderByProject).toEqual({});
});

test('keeps the local order when a newer acknowledgement supersedes deferred remote order', () => {
  reset();
  useWorktreeOrderStore.setState({ orderByProject: { project: ['/project/local'] }, pendingProjectIDs: { project: true } });
  useWorktreeOrderStore.getState().applyServerWorktreeOrder('project', ['/project/remote'], 10);
  useWorktreeOrderStore.getState().resolvePendingWorktreeOrder('project', 11);
  expect(useWorktreeOrderStore.getState().orderByProject).toEqual({ project: ['/project/local'] });
  expect(useWorktreeOrderStore.getState().serverRevisionByProject).toEqual({ project: 11 });
  expect(useWorktreeOrderStore.getState().pendingProjectIDs).toEqual({});
  expect(useWorktreeOrderStore.getState().deferredServerOrderByProject).toEqual({});
});

test('partitions persisted local order and pending intent by runtime identity', () => {
  reset();
  const unregister = registerWorktreeOrderWriter(() => {});
  try {
    useWorktreeOrderStore.getState().setWorktreeOrder('project', '/project', ['/runtime-a']);
    useWorktreeOrderStore.getState().activateWorktreeOrderRuntime('runtime-b');
    expect(useWorktreeOrderStore.getState().orderByProject).toEqual({});
    useWorktreeOrderStore.getState().setWorktreeOrder('project', '/project', ['/runtime-b']);
    useWorktreeOrderStore.getState().activateWorktreeOrderRuntime('runtime-a');
    expect(useWorktreeOrderStore.getState().orderByProject).toEqual({ project: ['/runtime-a'] });
    expect(useWorktreeOrderStore.getState().pendingProjectIDs).toEqual({ project: true });
    useWorktreeOrderStore.getState().activateWorktreeOrderRuntime('runtime-b');
    expect(useWorktreeOrderStore.getState().orderByProject).toEqual({ project: ['/runtime-b'] });
  } finally {
    unregister();
  }
});
