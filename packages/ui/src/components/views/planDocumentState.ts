type PlanDocumentState = { identity: string | null; path: string | null; content: string; baseContent: string };
type PlanSaveState = { persisted: string; desired: string; inFlight: string | null };

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

export const canApplyPlanSave = (
  capturedIdentity: string,
  currentIdentity: string | null,
  capturedGeneration: number,
  currentGeneration: number,
): boolean => capturedIdentity === currentIdentity && capturedGeneration === currentGeneration;

export const createPlanSaveState = (content: string): PlanSaveState => ({ persisted: content, desired: content, inFlight: null });

export const setPlanSaveDesired = (state: PlanSaveState, content: string): PlanSaveState => ({ ...state, desired: content });

export const startPlanSave = (state: PlanSaveState): [PlanSaveState, string | null] => {
  if (state.inFlight || state.desired === state.persisted) return [state, null];
  return [{ ...state, inFlight: state.desired }, state.desired];
};

export const finishPlanSave = (state: PlanSaveState, content: string): PlanSaveState => ({
  ...state,
  persisted: content,
  inFlight: state.inFlight === content ? null : state.inFlight,
});

export const failPlanSave = (state: PlanSaveState, attemptedContent: string): PlanSaveState => ({
  ...state,
  inFlight: state.inFlight === attemptedContent ? null : state.inFlight,
});

export const shouldShowMissingPlan = (
  queryIsMissing: boolean,
  state: Pick<PlanDocumentState, 'path' | 'content' | 'baseContent'>,
): boolean => queryIsMissing && state.path === null && state.content === state.baseContent;

export const canSavePlanDocument = (planEnabled: boolean, path: string | null): boolean => planEnabled && path !== null;
