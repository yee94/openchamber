import { describe, expect, test } from 'bun:test';
import { applyPlanSnapshot, canDrainPlanSave, canSavePlanDocument, createPlanSaveState, failPlanSave, finishPlanSave, initialPlanDocumentState, isPlanSaveStateClean, restorePlanDocumentSaveState, retryPlanSave, setPlanSaveDesired, shouldFlushPlanSaveOnBoundary, shouldShowMissingPlan, startPlanSave, startPlanSaveForTransport } from './planDocumentState';

describe('planDocumentState', () => {
  test('initial snapshot is clean and does not describe a saveable edit', () => {
    const state = applyPlanSnapshot(initialPlanDocumentState, 'a', { path: '/a.md', content: 'initial' }, false);
    expect(state).toEqual({ identity: 'a', path: '/a.md', content: 'initial', baseContent: 'initial' });
  });
  test('dirty draft survives a background snapshot while a clean document accepts it', () => {
    const dirty = { identity: 'a', path: '/a.md', content: 'draft', baseContent: 'base' };
    expect(applyPlanSnapshot(dirty, 'a', { path: '/a.md', content: 'remote' }, false)).toEqual(dirty);
    expect(applyPlanSnapshot({ ...dirty, content: 'base' }, 'a', { path: '/a.md', content: 'remote' }, false).content).toBe('remote');
  });
  test('a new identity replaces an old save document and empty edits remain saveable', () => {
    const next = applyPlanSnapshot({ identity: 'old', path: '/old.md', content: 'draft', baseContent: 'base' }, 'new', { path: '/new.md', content: '' }, false);
    expect(next).toEqual({ identity: 'new', path: '/new.md', content: '', baseContent: '' });
    expect({ content: '', baseContent: 'text' }.content !== { content: '', baseContent: 'text' }.baseContent).toBe(true);
    expect(canDrainPlanSave('old', 'new')).toBe(false);
  });
  test('accepts a remote snapshot when returning to a clean document', () => {
    const cleanA = createPlanSaveState('A0');
    const remoteA = applyPlanSnapshot({ identity: 'b', path: '/b.md', content: 'B0', baseContent: 'B0' }, 'a', { path: '/a.md', content: 'A1' }, false);

    expect(isPlanSaveStateClean(cleanA)).toBe(true);
    expect(remoteA).toEqual({ identity: 'a', path: '/a.md', content: 'A1', baseContent: 'A1' });
  });
  test('drains A2 after A1 succeeds', () => {
    let state = setPlanSaveDesired(createPlanSaveState('A0'), 'A1');
    const [startedState, attempt] = startPlanSave(state);
    state = startedState;
    state = setPlanSaveDesired(state, 'A2');
    state = finishPlanSave(state, attempt!);
    const [drainingState, nextAttempt] = startPlanSave(state);

    expect(nextAttempt?.content).toBe('A2');
    expect(drainingState.inFlight?.revision).toBe(2);
  });
  test('drains A2 after A1 fails', () => {
    let state = setPlanSaveDesired(createPlanSaveState('A0'), 'A1');
    const [startedState, attempt] = startPlanSave(state);
    state = startedState;
    state = setPlanSaveDesired(state, 'A2');
    state = failPlanSave(state, attempt!, 'failed');
    const [drainingState, nextAttempt] = startPlanSave(state);

    expect(nextAttempt?.content).toBe('A2');
    expect(drainingState.inFlight?.revision).toBe(2);
  });
  test('continues an inactive document drain for A2 after A1 completes', () => {
    let state = setPlanSaveDesired(createPlanSaveState('A0'), 'A1');
    const [startedState, a1] = startPlanSaveForTransport(state, 'runtime', 'runtime');
    state = setPlanSaveDesired(startedState, 'A2');
    state = finishPlanSave(state, a1!);
    const [, a2] = startPlanSaveForTransport(state, 'runtime', 'runtime');

    expect(a2?.content).toBe('A2');
  });
  test('ignores a completion with a different attempt token', () => {
    let state = setPlanSaveDesired(createPlanSaveState('A0'), 'A1');
    const [startedState, attempt] = startPlanSave(state);
    state = startedState;
    state = finishPlanSave(state, { ...attempt!, token: attempt!.token + 1 });

    expect(state.inFlight?.token).toBe(attempt!.token);
    expect(state.persisted).toBe('A0');
  });
  test('restores A state after visiting B', () => {
    const states = new Map<string, ReturnType<typeof createPlanSaveState>>();
    let a = setPlanSaveDesired(createPlanSaveState('A0'), 'A1');
    const [startedState, attempt] = startPlanSave(a);
    a = startedState;
    a = failPlanSave(a, attempt!, 'failed');
    states.set('a', a);
    states.set('b', setPlanSaveDesired(createPlanSaveState('B0'), 'B1'));
    const restored = restorePlanDocumentSaveState('a', '/a.md', states.get('a')!);

    expect(restored.baseContent).toBe('A0');
    expect(restored.content).toBe('A1');
    expect(states.get('a')?.failed?.error).toBe('failed');
  });
  test('stops a failed revision and force retry starts the same desired content', () => {
    let state = setPlanSaveDesired(createPlanSaveState('A0'), 'A1');
    const [startedState, attempt] = startPlanSave(state);
    state = startedState;
    state = failPlanSave(state, attempt!, 'failed');
    expect(startPlanSave(state)[1]).toBeNull();

    state = retryPlanSave(state);
    expect(startPlanSave(state)[1]?.content).toBe('A1');
  });
  test('clears an old failure after a newer revision succeeds', () => {
    let state = setPlanSaveDesired(createPlanSaveState('A0'), 'A1');
    const [startedA1, a1] = startPlanSave(state);
    state = setPlanSaveDesired(startedA1, 'A2');
    state = failPlanSave(state, a1!, 'failed');
    const [startedA2, a2] = startPlanSave(state);
    state = finishPlanSave(startedA2, a2!);

    expect(state.failed).toBeNull();
  });
  test('flushes dirty debounce state at an identity boundary and unmount boundary', () => {
    const dirty = setPlanSaveDesired(createPlanSaveState('A0'), 'A1');

    expect(shouldFlushPlanSaveOnBoundary(dirty)).toBe(true);
    expect(shouldFlushPlanSaveOnBoundary(createPlanSaveState('A0'))).toBe(false);
  });
  test('stops an old runtime worker before it drains its next desired revision', () => {
    const state = setPlanSaveDesired(createPlanSaveState('A0'), 'A1');

    expect(canDrainPlanSave('runtime-a', 'runtime-b')).toBe(false);
    expect(startPlanSaveForTransport(state, 'runtime-a', 'runtime-b')[1]).toBeNull();
    expect(startPlanSaveForTransport(state, 'runtime-b', 'runtime-b')[1]?.content).toBe('A1');
  });
  test('keeps a dirty resolved document saveable when its background query becomes missing', () => {
    const dirty = { path: '/plan.md', content: 'draft', baseContent: 'base' };
    expect(shouldShowMissingPlan(true, dirty)).toBe(false);
    expect(canSavePlanDocument(true, dirty.path)).toBe(true);
    expect(shouldShowMissingPlan(true, { path: null, content: '', baseContent: '' })).toBe(true);
  });
});
