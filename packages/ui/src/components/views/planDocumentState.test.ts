import { describe, expect, test } from 'bun:test';
import { applyPlanSnapshot, canApplyPlanSave, canSavePlanDocument, createPlanSaveState, failPlanSave, finishPlanSave, initialPlanDocumentState, setPlanSaveDesired, shouldShowMissingPlan, startPlanSave } from './planDocumentState';

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
    expect(canApplyPlanSave('old', 'new', 1, 2)).toBe(false);
  });
  test('queues a restored value after an in-flight different value persists', () => {
    let state = setPlanSaveDesired(createPlanSaveState('A'), 'B');
    let next: string | null;
    [state, next] = startPlanSave(state);
    expect(next).toBe('B');
    state = setPlanSaveDesired(state, 'A');
    state = finishPlanSave(state, 'B');
    [state, next] = startPlanSave(state);
    expect(next).toBe('A');
  });
  test('releases a failed write and starts the latest desired draft', () => {
    let state = setPlanSaveDesired(createPlanSaveState('A'), 'B');
    [state] = startPlanSave(state);
    state = setPlanSaveDesired(state, 'C');
    state = failPlanSave(state, 'B');
    const [startedState, next] = startPlanSave(state);
    state = startedState;
    expect(next).toBe('C');
    expect(finishPlanSave(state, 'C').persisted).toBe('C');
  });
  test('keeps a dirty resolved document saveable when its background query becomes missing', () => {
    const dirty = { path: '/plan.md', content: 'draft', baseContent: 'base' };
    expect(shouldShowMissingPlan(true, dirty)).toBe(false);
    expect(canSavePlanDocument(true, dirty.path)).toBe(true);
    expect(shouldShowMissingPlan(true, { path: null, content: '', baseContent: '' })).toBe(true);
  });
});
