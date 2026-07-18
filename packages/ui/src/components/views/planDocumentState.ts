type PlanDocumentState = { identity: string | null; path: string | null; content: string; baseContent: string };
type PlanSaveAttempt = { content: string; revision: number; token: number };
type PlanSaveFailure = { error: string; revision: number };
type PlanSaveState = {
  persisted: string;
  desired: string;
  desiredRevision: number;
  nextAttemptToken: number;
  inFlight: PlanSaveAttempt | null;
  failed: PlanSaveFailure | null;
};

export const initialPlanDocumentState: PlanDocumentState = { identity: null, path: null, content: '', baseContent: '' };

export const applyPlanSnapshot = (
  state: PlanDocumentState,
  identity: string,
  snapshot: { path: string; content: string } | null,
  savePending: boolean,
): PlanDocumentState => {
  if (state.identity !== identity) return { identity, path: snapshot?.path ?? null, content: snapshot?.content ?? '', baseContent: snapshot?.content ?? '' };
  if (state.content === state.baseContent && !savePending) return { ...state, path: snapshot?.path ?? null, content: snapshot?.content ?? '', baseContent: snapshot?.content ?? '' };
  return state;
};

export const createPlanSaveState = (content: string): PlanSaveState => ({
  persisted: content,
  desired: content,
  desiredRevision: 0,
  nextAttemptToken: 1,
  inFlight: null,
  failed: null,
});

export const setPlanSaveDesired = (state: PlanSaveState, content: string): PlanSaveState => {
  if (state.desired === content) return state;
  return { ...state, desired: content, desiredRevision: state.desiredRevision + 1, failed: null };
};

export const isPlanSaveStateClean = (state: PlanSaveState): boolean => (
  state.desired === state.persisted && state.inFlight === null && state.failed === null
);

export const restorePlanDocumentSaveState = (identity: string, path: string | null, state: PlanSaveState): PlanDocumentState => ({
  identity,
  path,
  content: state.desired,
  baseContent: state.persisted,
});

export const startPlanSave = (state: PlanSaveState): [PlanSaveState, PlanSaveAttempt | null] => {
  if (state.inFlight || state.desired === state.persisted || state.failed?.revision === state.desiredRevision) return [state, null];
  const attempt = { content: state.desired, revision: state.desiredRevision, token: state.nextAttemptToken };
  return [{ ...state, inFlight: attempt, nextAttemptToken: attempt.token + 1 }, attempt];
};

export const finishPlanSave = (state: PlanSaveState, attempt: PlanSaveAttempt): PlanSaveState => {
  if (state.inFlight?.token !== attempt.token) return state;
  return {
    ...state,
    persisted: attempt.content,
    inFlight: null,
    failed: state.failed && state.failed.revision > attempt.revision ? state.failed : null,
  };
};

export const failPlanSave = (state: PlanSaveState, attempt: PlanSaveAttempt, error: string): PlanSaveState => {
  if (state.inFlight?.token !== attempt.token) return state;
  return { ...state, inFlight: null, failed: { revision: attempt.revision, error } };
};

export const retryPlanSave = (state: PlanSaveState): PlanSaveState => ({ ...state, failed: null });

export const canDrainPlanSave = <Transport>(capturedTransport: Transport, currentTransport: Transport): boolean => capturedTransport === currentTransport;

export const startPlanSaveForTransport = <Transport>(
  state: PlanSaveState,
  capturedTransport: Transport,
  currentTransport: Transport,
): [PlanSaveState, PlanSaveAttempt | null] => canDrainPlanSave(capturedTransport, currentTransport)
  ? startPlanSave(state)
  : [state, null];

export const shouldFlushPlanSaveOnBoundary = (state: PlanSaveState): boolean => state.desired !== state.persisted || state.inFlight !== null;

export const prunePlanSaveStates = (states: Map<string, PlanSaveState>, activeIdentity: string | null, maximumEntries = 32): string[] => {
  const removed: string[] = [];
  for (const [identity, state] of states) {
    if (states.size <= maximumEntries) return removed;
    if (identity !== activeIdentity && isPlanSaveStateClean(state)) {
      states.delete(identity);
      removed.push(identity);
    }
  }
  return removed;
};

export const finishPlanSaveForDocument = (states: Map<string, PlanSaveState>, identity: string, attempt: PlanSaveAttempt): void => {
  const state = states.get(identity);
  if (state) states.set(identity, finishPlanSave(state, attempt));
};

export const failPlanSaveForDocument = (states: Map<string, PlanSaveState>, identity: string, attempt: PlanSaveAttempt, error: string): void => {
  const state = states.get(identity);
  if (state) states.set(identity, failPlanSave(state, attempt, error));
};

export const shouldShowMissingPlan = (
  queryIsMissing: boolean,
  state: Pick<PlanDocumentState, 'path' | 'content' | 'baseContent'>,
): boolean => queryIsMissing && state.path === null && state.content === state.baseContent;

export const canSavePlanDocument = (planEnabled: boolean, path: string | null): boolean => planEnabled && path !== null;
