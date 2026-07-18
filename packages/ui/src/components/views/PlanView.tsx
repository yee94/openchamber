import React from 'react';
import { runtimeFetch } from '@/lib/runtime-fetch';
import { useQueryClient } from '@tanstack/react-query';
import { CodeMirrorEditor } from '@/components/ui/CodeMirrorEditor';
import { PreviewToggleButton } from './PreviewToggleButton';
import { SimpleMarkdownRenderer } from '@/components/chat/MarkdownRenderer';
import { ErrorBoundary } from '@/components/ui/ErrorBoundary';
import { ScrollableOverlay } from '@/components/ui/ScrollableOverlay';
import { Button } from '@/components/ui/button';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { buildCodeMirrorCommentWidgets, normalizeLineRange, useInlineCommentController } from '@/components/comments';

import { getLanguageFromExtension } from '@/lib/toolHelpers';
import { useDeviceInfo } from '@/lib/device';
import { useThemeSystem } from '@/contexts/useThemeSystem';
import { createFlexokiCodeMirrorTheme } from '@/lib/codemirror/flexokiTheme';
import { shikiHighlightExtension } from '@/lib/codemirror/shikiHighlight';
import { getResolvedShikiTheme } from '@/lib/shiki/appThemeRegistry';
import { languageByExtension } from '@/lib/codemirror/languageByExtension';
import { useSessionUIStore } from '@/sync/session-ui-store';
import { useSessions } from '@/sync/sync-context';
import { useDirectoryStore } from '@/stores/useDirectoryStore';
import { useFeatureFlagsStore } from '@/stores/useFeatureFlagsStore';
import { useProjectsStore } from '@/stores/useProjectsStore';
import { useSelectionStore } from '@/sync/selection-store';
import { useConfigStore } from '@/stores/useConfigStore';
import { useSessionGoalArmStore } from '@/stores/useSessionGoalArmStore';
import { useUIStore } from '@/stores/useUIStore';
import { useGitStore } from '@/stores/useGitStore';
import { useRuntimeAPIs } from '@/hooks/useRuntimeAPIs';
import { useEffectiveDirectory } from '@/hooks/useEffectiveDirectory';
import { EditorView } from '@codemirror/view';
import { copyTextToClipboard } from '@/lib/clipboard';
import { generateBranchName } from '@/lib/git/branchNameGenerator';
import { parseProjectPlanMarkdown } from '@/lib/openchamberConfig';
import { createWorktreeSessionForNewBranch } from '@/lib/worktreeSessionCreator';
import { TodoSendDialog, type TodoSendExecution } from '@/components/session/TodoSendDialog';
import { Icon } from "@/components/icon/Icon";
import { useMessageTTS } from '@/hooks/useMessageTTS';
import { renderMagicPrompt } from '@/lib/magicPrompts';
import { useI18n } from '@/lib/i18n';
import { resolvePlanSource, usePlanResolvedQuery, type ResolvedPlan } from '@/queries/planQueries';
import { fileContentQueryKey, setFileContentSnapshot } from '@/queries/fileQueries';
import { getRuntimeTransportIdentity } from '@/lib/runtime-switch';
import { queryKeys } from '@/lib/queryRuntime';
import { applyPlanSnapshot, canSavePlanDocument, createPlanSaveState, failPlanSaveForDocument, finishPlanSaveForDocument, isPlanSaveStateClean, prunePlanSaveStates, restorePlanDocumentSaveState, retryPlanSave, setPlanSaveDesired, shouldFlushPlanSaveOnBoundary, shouldShowMissingPlan, startPlanSaveForTransport } from './planDocumentState';

type PlanViewProps = {
  targetPath?: string | null;
};

type PlanSendAction = 'improve' | 'implement';
type PlanSendTarget = 'session' | 'worktree';

type PendingPlanSend = {
  action: PlanSendAction;
  target: PlanSendTarget;
};

type PlanSaveContext = {
  identity: string;
  transport: ReturnType<typeof getRuntimeTransportIdentity>;
  path: string;
  scopeDirectory: string | null;
  planKey: unknown;
  planInput: unknown;
  write: (content: string) => Promise<void>;
  commit: (content: string) => Promise<void>;
};

const normalize = (value: string): string => {
  if (!value) return '';
  const replaced = value.replace(/\\/g, '/');
  return replaced === '/' ? '/' : replaced.replace(/\/+$/, '');
};

const joinPath = (base: string, segment: string): string => {
  const normalizedBase = normalize(base);
  const cleanSegment = segment.replace(/\\/g, '/').replace(/^\/+/, '').replace(/\/+$/, '');
  if (!normalizedBase || normalizedBase === '/') {
    return `/${cleanSegment}`;
  }
  return `${normalizedBase}/${cleanSegment}`;
};

const buildRepoPlanPath = (directory: string, created: number, slug: string): string => {
  return joinPath(joinPath(joinPath(directory, '.opencode'), 'plans'), `${created}-${slug}.md`);
};

const buildHomePlanPath = (created: number, slug: string): string => {
  return `~/.opencode/plans/${created}-${slug}.md`;
};

const resolveTilde = (path: string, homeDir: string | null): string => {
  const trimmed = path.trim();
  if (!trimmed.startsWith('~')) return trimmed;
  if (trimmed === '~') return homeDir || trimmed;
  if (trimmed.startsWith('~/') || trimmed.startsWith('~\\')) {
    return homeDir ? `${homeDir}${trimmed.slice(1)}` : trimmed;
  }
  return trimmed;
};

const toDisplayPath = (resolvedPath: string, options: { currentDirectory: string; homeDirectory: string }): string => {
  const current = normalize(options.currentDirectory);
  const home = normalize(options.homeDirectory);
  const normalized = normalize(resolvedPath);

  if (current && normalized.startsWith(current + '/')) {
    return normalized.slice(current.length + 1);
  }

  if (home && normalized === home) {
    return '~';
  }

  if (home && normalized.startsWith(home + '/')) {
    return `~${normalized.slice(home.length)}`;
  }

  return normalized;
};

const resolveProjectRefForDirectory = (
  directory: string,
  projects: Array<{ id: string; path: string }>,
  activeProjectId: string | null,
): { id: string; path: string } | null => {
  const normalized = normalize(directory.trim());
  if (!normalized) {
    return null;
  }

  const activeProject = activeProjectId
    ? projects.find((project) => project.id === activeProjectId) ?? null
    : null;

  if (activeProject?.path) {
    const activePath = normalize(activeProject.path);
    if (normalized === activePath || normalized.startsWith(`${activePath}/`)) {
      return { id: activeProject.id, path: activeProject.path };
    }
  }

  const match = projects
    .filter((project) => {
      const projectPath = normalize(project.path);
      return normalized === projectPath || normalized.startsWith(`${projectPath}/`);
    })
    .sort((left, right) => normalize(right.path).length - normalize(left.path).length)[0];

  return match ? { id: match.id, path: match.path } : null;
};

type SelectedLineRange = {
  start: number;
  end: number;
};

export const PlanView: React.FC<PlanViewProps> = ({ targetPath = null }) => {
  const { t } = useI18n();
  const currentSessionId = useSessionUIStore((state) => state.currentSessionId);
  const createSession = useSessionUIStore((state) => state.createSession);
  const initializeNewOpenChamberSession = useSessionUIStore((state) => state.initializeNewOpenChamberSession);
  const sendMessage = useSessionUIStore((state) => state.sendMessage);
  const setCurrentSession = useSessionUIStore((state) => state.setCurrentSession);
  const sessions = useSessions();
  const homeDirectory = useDirectoryStore((state) => state.homeDirectory);
  const planModeEnabled = useFeatureFlagsStore((state) => state.planModeEnabled);
  const projects = useProjectsStore((state) => state.projects);
  const activeProjectId = useProjectsStore((state) => state.activeProjectId);
  const gitDirectories = useGitStore((state) => state.directories);
  const effectiveDirectory = useEffectiveDirectory() ?? '';
  const setActiveMainTab = useUIStore((state) => state.setActiveMainTab);
  const setSessionSwitcherOpen = useUIStore((state) => state.setSessionSwitcherOpen);
  const runtimeApis = useRuntimeAPIs();
  const queryClient = useQueryClient();
  const { isMobile } = useDeviceInfo();
  const { currentTheme } = useThemeSystem();

  const session = React.useMemo(() => {
    if (!currentSessionId) return null;
    return sessions.find((s) => s.id === currentSessionId) ?? null;
  }, [currentSessionId, sessions]);

  const sessionDirectory = React.useMemo(() => {
    const raw = typeof session?.directory === 'string' ? session.directory : '';
    return normalize(raw || '');
  }, [session?.directory]);
  const projectDirectory = React.useMemo(
    () => normalize(effectiveDirectory || sessionDirectory),
    [effectiveDirectory, sessionDirectory],
  );
  const currentProjectRef = React.useMemo(
    () => resolveProjectRefForDirectory(projectDirectory, projects, activeProjectId),
    [activeProjectId, projectDirectory, projects],
  );
  const canCreateWorktree = React.useMemo(
    () => (currentProjectRef ? gitDirectories.get(currentProjectRef.path)?.isGitRepo === true : false),
    [currentProjectRef, gitDirectories],
  );
  const [pendingPlanSend, setPendingPlanSend] = React.useState<PendingPlanSend | null>(null);
  const [isPlanSendSubmitting, setIsPlanSendSubmitting] = React.useState(false);

  const [resolvedPath, setResolvedPath] = React.useState<string | null>(null);
  const displayPath = React.useMemo(() => {
    if (!resolvedPath || !sessionDirectory || !homeDirectory) {
      return resolvedPath;
    }
    return toDisplayPath(resolvedPath, { currentDirectory: sessionDirectory, homeDirectory });
  }, [resolvedPath, sessionDirectory, homeDirectory]);
  const [content, setContent] = React.useState<string>('');
  const [baseContent, setBaseContent] = React.useState<string>('');
  const { isPlaying: isTTSPlaying, play: playTTS, stop: stopTTS } = useMessageTTS();
  const showMessageTTSButtons = useConfigStore((state) => state.showMessageTTSButtons);
  const [saveError, setSaveError] = React.useState<string | null>(null);
  const [saveRetry, setSaveRetry] = React.useState(0);
  const planFileLabel = React.useMemo(() => {
    return displayPath ? displayPath.split('/').pop() || t('planView.file.defaultName') : t('planView.file.defaultName');
  }, [displayPath, t]);
  const parsedTitle = React.useMemo(() => {
    if (!content.trim()) {
      return t('planView.title.default');
    }
    return parseProjectPlanMarkdown(content).title || t('planView.title.default');
  }, [content, t]);
  const sendPromptTitle = React.useMemo(() => parsedTitle.trim() || t('planView.title.default'), [parsedTitle, t]);
  const [copiedContent, setCopiedContent] = React.useState(false);
  const [mdViewMode, setMdViewMode] = React.useState<'preview' | 'edit'>('edit');
  const copiedContentTimeoutRef = React.useRef<number | null>(null);
  const isMountedRef = React.useRef(true);
  const planSaveStatesRef = React.useRef(new Map<string, ReturnType<typeof createPlanSaveState>>());
  const saveTimersRef = React.useRef(new Map<string, number>());
  const saveWorkersRef = React.useRef(new Map<string, Promise<void>>());
  const saveContextsRef = React.useRef(new Map<string, PlanSaveContext>());
  const drainPlanSaveRef = React.useRef<(context: PlanSaveContext) => void>(() => {});
  const documentIdentityRef = React.useRef<string | null>(null);

  const [lineSelection, setLineSelection] = React.useState<SelectedLineRange | null>(null);
  const editorViewRef = React.useRef<EditorView | null>(null);
  const editorWrapperRef = React.useRef<HTMLDivElement | null>(null);

  React.useEffect(() => {
    isMountedRef.current = true;
    const saveTimers = saveTimersRef.current;
    const saveContexts = saveContextsRef.current;
    const planSaveStates = planSaveStatesRef.current;
    return () => {
      isMountedRef.current = false;
      for (const timer of saveTimers.values()) {
        window.clearTimeout(timer);
      }
      saveTimers.clear();
      for (const [identity, context] of saveContexts) {
        const state = planSaveStates.get(identity);
        if (state && shouldFlushPlanSaveOnBoundary(state)) drainPlanSaveRef.current(context);
      }
    };
  }, []);

  const MD_VIEWER_MODE_KEY = 'openchamber:plan:md-viewer-mode';

  React.useEffect(() => {
    try {
      const stored = localStorage.getItem(MD_VIEWER_MODE_KEY);
      if (!stored) return;
      const parsed = JSON.parse(stored) as unknown;
      if (parsed === 'preview' || parsed === 'edit') {
        setMdViewMode(parsed);
      }
    } catch {
      // ignore
    }
  }, []);

  const saveMdViewMode = React.useCallback((mode: 'preview' | 'edit') => {
    setMdViewMode(mode);
    try {
      localStorage.setItem(MD_VIEWER_MODE_KEY, JSON.stringify(mode));
    } catch {
      // ignore
    }
  }, []);
  const isSelectingRef = React.useRef(false);
  const selectionStartRef = React.useRef<number | null>(null);
  const [isDragging, setIsDragging] = React.useState(false);

  React.useEffect(() => {
    const handleGlobalMouseUp = () => {
      isSelectingRef.current = false;
      selectionStartRef.current = null;
      setIsDragging(false);
    };
    document.addEventListener('mouseup', handleGlobalMouseUp);
    return () => document.removeEventListener('mouseup', handleGlobalMouseUp);
  }, []);

  const extractSelectedCode = React.useCallback((text: string, range: SelectedLineRange): string => {
    const lines = text.split('\n');
    const startLine = Math.max(1, range.start);
    const endLine = Math.min(lines.length, range.end);
    if (startLine > endLine) return '';
    return lines.slice(startLine - 1, endLine).join('\n');
  }, []);

  const commentController = useInlineCommentController<SelectedLineRange>({
    source: 'plan',
    fileLabel: planFileLabel,
    language: resolvedPath ? getLanguageFromExtension(resolvedPath) || 'markdown' : 'markdown',
    getCodeForRange: (range) => extractSelectedCode(content, normalizeLineRange(range)),
    toStoreRange: (range) => ({ startLine: range.start, endLine: range.end }),
    fromDraftRange: (draft) => ({ start: draft.startLine, end: draft.endLine }),
  });

  const {
    drafts: planFileDrafts,
    commentText,
    setCommentText,
    editingDraftId,
    setSelection: setCommentSelection,
    saveComment,
    cancel,
    reset,
    startEdit,
    deleteDraft,
  } = commentController;

  React.useEffect(() => {
    setLineSelection(null);
    reset();
  }, [content, reset]);

  React.useEffect(() => {
    setCommentSelection(lineSelection);
  }, [lineSelection, setCommentSelection]);

  const handleCancelComment = React.useCallback(() => {
    setLineSelection(null);
    cancel();
  }, [cancel]);

  const handleSaveComment = React.useCallback((textToSave: string, rangeOverride?: { start: number; end: number }) => {
    if (rangeOverride) {
      setLineSelection(rangeOverride);
    }
    saveComment(textToSave, rangeOverride ?? lineSelection ?? undefined);
    setLineSelection(null);
  }, [lineSelection, saveComment]);

  React.useEffect(() => {
    if (!lineSelection) return;

    if (isMobile && !editingDraftId) {
      // Input handles mobile scroll/focus behavior.
    }

    const handleClickOutside = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      if (
        target.closest('[data-comment-card="true"]') ||
        target.closest('[data-comment-input="true"]') ||
        target.closest('.oc-block-widget')
      ) {
        return;
      }

      if (target.closest('.cm-gutterElement')) return;
      if (target.closest('[data-sonner-toast]') || target.closest('[data-sonner-toaster]')) return;

      if (!commentText.trim()) {
        setLineSelection(null);
        cancel();
      }
    };

    const timeoutId = window.setTimeout(() => {
      document.addEventListener('click', handleClickOutside);
    }, 100);

    return () => {
      window.clearTimeout(timeoutId);
      document.removeEventListener('click', handleClickOutside);
    };
  }, [cancel, commentText, editingDraftId, isMobile, lineSelection]);

  const editorFontSize = useUIStore((state) => state.editorFontSize);

  const editorExtensions = React.useMemo(() => {
    // Shiki token colors only for code files; markdown keeps the lezer
    // highlighter (markdown-aware bold headings etc., and no Shiki view to match).
    const shikiLanguage = resolvedPath ? getLanguageFromExtension(resolvedPath) : null;
    const useShiki = Boolean(shikiLanguage) && shikiLanguage !== 'markdown';
    const extensions = [createFlexokiCodeMirrorTheme(currentTheme, useShiki ? { syntaxColors: false, fontSize: editorFontSize } : { fontSize: editorFontSize })];
    const language = languageByExtension(resolvedPath || 'plan.md');
    if (language) {
      extensions.push(language);
    }
    if (useShiki && shikiLanguage) {
      extensions.push(shikiHighlightExtension({
        language: shikiLanguage,
        themeName: currentTheme.metadata.id,
        theme: getResolvedShikiTheme(currentTheme),
      }));
    }
    extensions.push(EditorView.lineWrapping);
    return extensions;
  }, [currentTheme, resolvedPath, editorFontSize]);

  const planInput = React.useMemo(() => ({
    mode: targetPath ? 'target' as const : 'session' as const,
    sessionId: currentSessionId,
    scopeDirectory: sessionDirectory || null,
    targetPath: targetPath || null,
    repoPath: !targetPath && session?.slug && session?.time?.created && sessionDirectory
      ? buildRepoPlanPath(sessionDirectory, session.time.created, session.slug) : null,
    homePath: !targetPath && session?.slug && session?.time?.created
      ? resolveTilde(buildHomePlanPath(session.time.created, session.slug), homeDirectory || null) : null,
  }), [currentSessionId, homeDirectory, session?.slug, session?.time?.created, sessionDirectory, targetPath]);
  const planEnabled = Boolean(targetPath || (planModeEnabled && planInput.repoPath && planInput.homePath));
  const planQuery = usePlanResolvedQuery(planInput, { enabled: planEnabled });
  const transport = getRuntimeTransportIdentity();
  const currentTransportRef = React.useRef(transport);
  currentTransportRef.current = transport;
  const planKey = React.useMemo(
    () => queryKeys.plans.resolved(planInput.mode, planInput.sessionId, planInput.scopeDirectory, planInput.targetPath, planInput.repoPath, planInput.homePath, transport),
    [planInput.homePath, planInput.mode, planInput.repoPath, planInput.scopeDirectory, planInput.sessionId, planInput.targetPath, transport],
  );
  const documentIdentity = React.useMemo(() => JSON.stringify(planKey), [planKey]);
  const loading = planEnabled && planQuery.isPending;
  const initialReadError = planEnabled && planQuery.isError && planQuery.data === undefined;
  const missingPlan = shouldShowMissingPlan(planEnabled && planQuery.data?.kind === 'missing', { path: resolvedPath, content, baseContent });
  const missingCandidates = planQuery.data?.kind === 'missing' ? planQuery.data.candidates : null;

  React.useEffect(() => {
    if (!planEnabled) {
      documentIdentityRef.current = null;
      setResolvedPath(null);
      setContent('');
      setBaseContent('');
      setSaveError(null);
      return;
    }
    const snapshot = planEnabled && planQuery.data?.kind === 'resolved'
      ? { path: planQuery.data.path, content: planQuery.data.content }
      : null;
    const previousIdentity = documentIdentityRef.current;
    const saveState = planSaveStatesRef.current.get(documentIdentity);
    let next = applyPlanSnapshot(
      { identity: documentIdentityRef.current, path: resolvedPath, content, baseContent },
      documentIdentity,
      snapshot,
      (saveState?.inFlight ?? null) !== null,
    );
    const identityChanged = documentIdentityRef.current !== documentIdentity;
    if (identityChanged && saveState && !isPlanSaveStateClean(saveState)) {
      const savedPath = saveContextsRef.current.get(documentIdentity)?.path ?? null;
      next = restorePlanDocumentSaveState(documentIdentity, snapshot?.path ?? savedPath, saveState);
    }
    if (identityChanged && previousIdentity) {
      const previousTimer = saveTimersRef.current.get(previousIdentity);
      if (previousTimer !== undefined) {
        window.clearTimeout(previousTimer);
        saveTimersRef.current.delete(previousIdentity);
      }
      const previousState = planSaveStatesRef.current.get(previousIdentity);
      const previousContext = saveContextsRef.current.get(previousIdentity);
      if (previousState && previousContext && shouldFlushPlanSaveOnBoundary(previousState)) {
        drainPlanSaveRef.current(previousContext);
      }
    }
    documentIdentityRef.current = documentIdentity;
    if (identityChanged || next.path !== resolvedPath || next.content !== content || next.baseContent !== baseContent) {
      setResolvedPath(next.path);
      setContent(next.content);
      setBaseContent(next.baseContent);
      if (identityChanged) setSaveError(planSaveStatesRef.current.get(documentIdentity)?.failed?.error ?? null);
    }
    if (!saveState || isPlanSaveStateClean(saveState)) {
      planSaveStatesRef.current.set(documentIdentity, createPlanSaveState(next.baseContent));
    }
    for (const identity of prunePlanSaveStates(planSaveStatesRef.current, documentIdentity)) {
      saveContextsRef.current.delete(identity);
    }
  }, [baseContent, content, documentIdentity, planEnabled, planQuery.data, resolvedPath]);

  const drainPlanSave = React.useCallback((context: PlanSaveContext) => {
    if (saveWorkersRef.current.has(context.identity)) return;
    const worker = (async () => {
      while (true) {
        const state = planSaveStatesRef.current.get(context.identity);
        if (!state) return;
        const [nextState, attempt] = startPlanSaveForTransport(state, context.transport, currentTransportRef.current);
        planSaveStatesRef.current.set(context.identity, nextState);
        if (!attempt) return;

        try {
          await context.write(attempt.content);
          await context.commit(attempt.content);
          finishPlanSaveForDocument(planSaveStatesRef.current, context.identity, attempt);
          for (const identity of prunePlanSaveStates(planSaveStatesRef.current, documentIdentityRef.current)) {
            saveContextsRef.current.delete(identity);
          }
          if (isMountedRef.current && documentIdentityRef.current === context.identity) {
            setBaseContent(attempt.content);
            setSaveError(null);
          }
        } catch (error) {
          const message = error instanceof Error ? error.message : t('planView.error.saveFailed');
          failPlanSaveForDocument(planSaveStatesRef.current, context.identity, attempt, message);
          const failedState = planSaveStatesRef.current.get(context.identity);
          const failedRevision = failedState?.failed?.revision;
          if (isMountedRef.current && documentIdentityRef.current === context.identity && failedState && failedRevision !== undefined && failedRevision === failedState.desiredRevision) {
            setSaveError(message);
          }
        }
      }
    })().finally(() => {
      saveWorkersRef.current.delete(context.identity);
    });
    saveWorkersRef.current.set(context.identity, worker);
  }, [t]);
  drainPlanSaveRef.current = drainPlanSave;

  React.useEffect(() => {
    const saveTimers = saveTimersRef.current;
    const saveState = planSaveStatesRef.current.get(documentIdentity) ?? createPlanSaveState(content);
    planSaveStatesRef.current.set(documentIdentity, setPlanSaveDesired(saveState, content));
    for (const identity of prunePlanSaveStates(planSaveStatesRef.current, documentIdentity)) {
      saveContextsRef.current.delete(identity);
    }
    if (!canSavePlanDocument(planEnabled, resolvedPath) || !resolvedPath) {
      if (isMountedRef.current && documentIdentityRef.current === documentIdentity) setSaveError(null);
      return;
    }

    const existingTimer = saveTimers.get(documentIdentity);
    if (existingTimer !== undefined) window.clearTimeout(existingTimer);
    const writeFile = runtimeApis.files?.writeFile;
    const context: PlanSaveContext = {
      identity: documentIdentity,
      transport,
      path: resolvedPath,
      scopeDirectory: planInput.scopeDirectory,
      planKey,
      planInput,
      write: async (contentToSave) => {
        if (writeFile) {
          const result = await writeFile(resolvedPath, contentToSave);
          if (!result?.success) throw new Error(t('planView.error.writeFailed'));
          return;
        }
        const response = await runtimeFetch('/api/fs/write', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', ...(planInput.scopeDirectory ? { 'x-opencode-directory': planInput.scopeDirectory } : {}) },
          body: JSON.stringify({ path: resolvedPath, content: contentToSave }),
        });
        if (!response.ok) throw new Error(t('planView.error.writePlanFileFailed', { status: response.status }));
      },
      commit: async (contentToSave) => {
        const fileInput = {
          scopeDirectory: planInput.scopeDirectory,
          path: resolvedPath,
          options: { optional: true, ...(planInput.scopeDirectory ? { directory: planInput.scopeDirectory } : {}) },
        };
        await queryClient.cancelQueries({ queryKey: fileContentQueryKey(fileInput, transport), exact: true });
        await queryClient.cancelQueries({ queryKey: planKey, exact: true });
        setFileContentSnapshot(queryClient, fileInput, transport, contentToSave);
        queryClient.setQueryData<ResolvedPlan>(planKey, () => ({
          kind: 'resolved',
          source: resolvePlanSource(planInput, resolvedPath),
          path: resolvedPath,
          content: contentToSave,
        }));
      },
    };
    saveContextsRef.current.set(documentIdentity, context);
    const controller = window.setTimeout(() => {
      saveTimers.delete(documentIdentity);
      drainPlanSave(context);
    }, 350);
    saveTimers.set(documentIdentity, controller);

    return () => {
      window.clearTimeout(controller);
      if (saveTimers.get(documentIdentity) === controller) saveTimers.delete(documentIdentity);
    };
  }, [content, documentIdentity, drainPlanSave, planEnabled, planInput, planKey, planQuery.data?.kind, queryClient, resolvedPath, runtimeApis.files, saveRetry, t, transport]);

  React.useEffect(() => {
    return () => {
      if (copiedContentTimeoutRef.current !== null) {
        window.clearTimeout(copiedContentTimeoutRef.current);
      }
    };
  }, []);

  const routeToChat = React.useCallback(() => {
    setActiveMainTab('chat');
    setSessionSwitcherOpen(false);
  }, [setActiveMainTab, setSessionSwitcherOpen]);

  const handleConfirmPlanSend = React.useCallback(
    async (execution: TodoSendExecution) => {
      if (!currentProjectRef || !pendingPlanSend) {
        return;
      }

      const visiblePrompt = await renderMagicPrompt(
        pendingPlanSend.action === 'improve' ? 'plan.improve.visible' : 'plan.implement.visible',
        {
          plan_title: sendPromptTitle,
        },
      );
      const instructionsText = await renderMagicPrompt(
        pendingPlanSend.action === 'improve' ? 'plan.improve.instructions' : 'plan.implement.instructions',
        {
          plan_title: sendPromptTitle,
          plan_path: resolvedPath ?? '',
        },
      );
      const syntheticParts = [{ synthetic: true as const, text: instructionsText }];
      setIsPlanSendSubmitting(true);

      try {
        routeToChat();

        let sessionId: string | null = null;
        let directoryHint: string | null = currentProjectRef.path;

        if (pendingPlanSend.target === 'worktree') {
          if (!canCreateWorktree) {
            return;
          }
          const created = await createWorktreeSessionForNewBranch(currentProjectRef.path, generateBranchName());
          if (!created?.id) {
            return;
          }
          sessionId = created.id;
          directoryHint = created.path;
        } else {
          const sessionResult = await createSession(undefined, currentProjectRef.path, null);
          if (!sessionResult?.id) {
            return;
          }
          sessionId = sessionResult.id;
          directoryHint = sessionResult.directory ?? currentProjectRef.path;
          initializeNewOpenChamberSession(sessionResult.id, useConfigStore.getState().agents ?? []);
        }

        if (!sessionId) {
          return;
        }

        const selectionState = useSelectionStore.getState();
        selectionState.saveSessionModelSelection(sessionId, execution.providerID, execution.modelID);
        if (execution.agent.trim()) {
          selectionState.saveSessionAgentSelection(sessionId, execution.agent);
          selectionState.saveAgentModelForSession(sessionId, execution.agent, execution.providerID, execution.modelID);
          selectionState.saveAgentModelVariantForSession(
            sessionId,
            execution.agent,
            execution.providerID,
            execution.modelID,
            execution.variant || undefined,
          );
        }

        setCurrentSession(sessionId, directoryHint);
        // "Run as goal" rides the same arm mechanism as the composer target
        // button; set explicitly either way so a stray armed flag cannot
        // leak into a non-goal plan send. The objective override carries the
        // plan substance — "Implement this plan: X" alone would give the
        // progress audit nothing to judge against. Plans that exceed the
        // objective limit are distilled into completion criteria by the
        // small model (the working agent always reads the full plan from
        // its file); on distillation failure a head+tail excerpt keeps the
        // intent (top) and acceptance criteria (bottom), sacrificing the
        // implementation middle the agent reads from the file anyway.
        // Oversized objectives (huge plans) are distilled into audit
        // criteria inside setSessionGoal — the shared path for every goal
        // source. Here we only compose header + full content.
        const goalObjective = execution.runAsGoal === true
          ? [
              `Implement the plan "${sendPromptTitle}" end-to-end${resolvedPath ? ` (plan file: ${resolvedPath})` : ''}.`,
              'Re-read that file for full details — it is the source of truth.',
              '',
              content,
            ].join('\n')
          : null;
        useSessionGoalArmStore.getState().setArmed(execution.runAsGoal === true, goalObjective);
        await sendMessage(
          visiblePrompt,
          execution.providerID,
          execution.modelID,
          execution.agent.trim() || undefined,
          undefined,
          undefined,
          syntheticParts,
          execution.variant || undefined,
        );

        setPendingPlanSend(null);
      } finally {
        setIsPlanSendSubmitting(false);
      }
    },
    [canCreateWorktree, content, createSession, currentProjectRef, initializeNewOpenChamberSession, pendingPlanSend, resolvedPath, routeToChat, sendMessage, sendPromptTitle, setCurrentSession]
  );

  const blockWidgets = React.useMemo(() => {
    return buildCodeMirrorCommentWidgets({
      drafts: planFileDrafts,
      editingDraftId,
      commentText,
      onTextChange: setCommentText,
      selection: lineSelection,
      isDragging,
      fileLabel: planFileLabel,
      newWidgetId: 'plan-new-comment-input',
      mapDraftToRange: (draft) => ({ start: draft.startLine, end: draft.endLine }),
      onSave: handleSaveComment,
      onCancel: handleCancelComment,
      onEdit: (draft) => {
        startEdit(draft);
        setLineSelection({ start: draft.startLine, end: draft.endLine });
      },
      onDelete: deleteDraft,
    });
  }, [commentText, deleteDraft, editingDraftId, handleCancelComment, handleSaveComment, isDragging, lineSelection, planFileDrafts, planFileLabel, setCommentText, startEdit]);

  return (
    <div className="relative flex h-full min-h-0 min-w-0 w-full flex-col overflow-hidden bg-background">
      <div className="flex min-w-0 items-center gap-2 border-b border-border/40 px-3 py-1.5 flex-shrink-0">
        <div className="min-w-0 flex-1">
          <div className="typography-ui-label font-medium truncate">{parsedTitle}</div>
          {saveError ? (
            <Button
              variant="link"
              size="xs"
              className="h-auto p-0 typography-micro text-[color:var(--status-error)]"
              title={saveError}
              onClick={() => {
                const saveState = planSaveStatesRef.current.get(documentIdentity);
                if (!saveState) return;
                planSaveStatesRef.current.set(documentIdentity, retryPlanSave(saveState));
                setSaveError(null);
                setSaveRetry((value) => value + 1);
              }}
            >
              {t('planView.error.saveFailed')}
            </Button>
          ) : null}
        </div>
        {resolvedPath ? (
          <div className="flex items-center gap-1">
            <DropdownMenu>
              <Tooltip>
                <TooltipTrigger asChild>
                  <DropdownMenuTrigger asChild>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-5 w-5 p-0"
                      aria-label={t('planView.actions.improvePlanAria')}
                      disabled={!content.trim()}
                    >
                      <Icon name="loop-right-ai" className="size-4" />
                    </Button>
                  </DropdownMenuTrigger>
                </TooltipTrigger>
                <TooltipContent sideOffset={8}>{t('planView.actions.improve')}</TooltipContent>
              </Tooltip>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={() => setPendingPlanSend({ action: 'improve', target: 'session' })}>
                  {t('planView.actions.sendToNewSession')}
                </DropdownMenuItem>
                <DropdownMenuItem
                  onClick={() => setPendingPlanSend({ action: 'improve', target: 'worktree' })}
                  disabled={!canCreateWorktree}
                >
                  {t('planView.actions.sendToNewWorktreeSession')}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
            <DropdownMenu>
              <Tooltip>
                <TooltipTrigger asChild>
                  <DropdownMenuTrigger asChild>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-5 w-5 p-0"
                      aria-label={t('planView.actions.implementPlanAria')}
                      disabled={!content.trim()}
                    >
                      <Icon name="code-ai" className="size-4" />
                    </Button>
                  </DropdownMenuTrigger>
                </TooltipTrigger>
                <TooltipContent sideOffset={8}>{t('planView.actions.implement')}</TooltipContent>
              </Tooltip>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={() => setPendingPlanSend({ action: 'implement', target: 'session' })}>
                  {t('planView.actions.sendToNewSession')}
                </DropdownMenuItem>
                <DropdownMenuItem
                  onClick={() => setPendingPlanSend({ action: 'implement', target: 'worktree' })}
                  disabled={!canCreateWorktree}
                >
                  {t('planView.actions.sendToNewWorktreeSession')}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
            <PreviewToggleButton
              currentMode={mdViewMode}
              onToggle={() => saveMdViewMode(mdViewMode === 'preview' ? 'edit' : 'preview')}
            />
            {mdViewMode === 'preview' && showMessageTTSButtons && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-5 w-5 p-0"
                    aria-label={isTTSPlaying ? t('planView.tts.stopSpeaking') : t('planView.tts.readAloud')}
                    onClick={() => {
                      if (isTTSPlaying) {
                        stopTTS();
                      } else if (content.trim()) {
                        void playTTS(content);
                      }
                    }}
                  >
                    {isTTSPlaying ? (
                      <Icon name="stop" className="h-4 w-4 text-[color:var(--status-success)]" />
                    ) : (
                      <Icon name="volume-up" className="h-4 w-4" />
                    )}
                  </Button>
                </TooltipTrigger>
                <TooltipContent sideOffset={8}>
                  {isTTSPlaying ? t('planView.tts.stopSpeaking') : t('planView.tts.readAloud')}
                </TooltipContent>
              </Tooltip>
            )}
            <Button
              variant="ghost"
              size="sm"
              onClick={async () => {
                const result = await copyTextToClipboard(content);
                if (result.ok) {
                  setCopiedContent(true);
                  if (copiedContentTimeoutRef.current !== null) {
                    window.clearTimeout(copiedContentTimeoutRef.current);
                  }
                  copiedContentTimeoutRef.current = window.setTimeout(() => {
                    setCopiedContent(false);
                  }, 1200);
                } else {
                  // ignored
                }
              }}
              className="h-5 w-5 p-0"
              title={t('planView.actions.copyPlanContents')}
              aria-label={t('planView.actions.copyPlanContents')}
            >
              {copiedContent ? (
                <Icon name="check" className="h-4 w-4 text-[color:var(--status-success)]" />
              ) : (
                <Icon name="clipboard" className="h-4 w-4" />
              )}
            </Button>
          </div>
        ) : null}
      </div>

      <TodoSendDialog
        open={pendingPlanSend !== null}
        onOpenChange={(open) => {
          if (!open && !isPlanSendSubmitting) {
            setPendingPlanSend(null);
          }
        }}
        target={pendingPlanSend?.target ?? 'session'}
        projectDirectory={currentProjectRef?.path ?? null}
        submitting={isPlanSendSubmitting}
        allowRunAsGoal
        onConfirm={handleConfirmPlanSend}
      />

      <div className="flex-1 min-h-0 min-w-0 relative">
        <ScrollableOverlay outerClassName="h-full min-w-0" className="h-full min-w-0">
          {loading ? (
            <div className="p-3 typography-ui text-muted-foreground">{t('planView.state.loading')}</div>
          ) : initialReadError ? (
            <div className="p-3 typography-ui text-destructive">{planQuery.error instanceof Error ? planQuery.error.message : t('planView.error.saveFailed')}</div>
          ) : missingPlan && missingCandidates ? (
            <div className="p-3 typography-ui text-muted-foreground">{missingCandidates.join(', ')}</div>
          ) : (
            <div className="relative h-full">
              <div className="h-full">
                {mdViewMode === 'preview' ? (
                  <div className="h-full overflow-auto p-3">
                    <ErrorBoundary
                      fallback={
                        <div className="rounded-md border border-destructive/20 bg-destructive/10 px-3 py-2">
                          <div className="mb-1 font-medium text-destructive">{t('planView.error.previewUnavailable')}</div>
                          <div className="text-sm text-muted-foreground">
                            {t('planView.error.switchToEditMode')}
                          </div>
                        </div>
                      }
                    >
                      <SimpleMarkdownRenderer content={content} className="typography-markdown-body" enableFileReferences={false} />
                    </ErrorBoundary>
                  </div>
                ) : (
                  <div className="relative h-full" ref={editorWrapperRef}>
                    <CodeMirrorEditor
                      value={content}
                      onChange={setContent}
                      readOnly={false}
                      className="h-full"
                      extensions={editorExtensions}
                      onViewReady={(view) => { editorViewRef.current = view; }}
                      onViewDestroy={() => { editorViewRef.current = null; }}
                      blockWidgets={blockWidgets}
                      highlightLines={lineSelection
                        ? {
                          start: Math.min(lineSelection.start, lineSelection.end),
                          end: Math.max(lineSelection.start, lineSelection.end),
                        }
                        : undefined}
                      lineNumbersConfig={{
                        domEventHandlers: {
                          mousedown: (view, line, event) => {
                            if (!(event instanceof MouseEvent)) return false;
                            if (event.button !== 0) return false;
                            event.preventDefault();
                            const lineNumber = view.state.doc.lineAt(line.from).number;

                            if (
                              lineSelection &&
                              !event.shiftKey &&
                              Math.min(lineSelection.start, lineSelection.end) === lineNumber &&
                              Math.max(lineSelection.start, lineSelection.end) === lineNumber
                            ) {
                              setLineSelection(null);
                              cancel();
                              isSelectingRef.current = false;
                              selectionStartRef.current = null;
                              setIsDragging(false);
                              return true;
                            }

                            if (isMobile && lineSelection && !event.shiftKey) {
                              const start = Math.min(lineSelection.start, lineSelection.end, lineNumber);
                              const end = Math.max(lineSelection.start, lineSelection.end, lineNumber);
                              setLineSelection({ start, end });
                              isSelectingRef.current = false;
                              selectionStartRef.current = null;
                              setIsDragging(false);
                              return true;
                            }

                            isSelectingRef.current = true;
                            selectionStartRef.current = lineNumber;
                            setIsDragging(true);

                            if (lineSelection && event.shiftKey) {
                              const start = Math.min(lineSelection.start, lineNumber);
                              const end = Math.max(lineSelection.end, lineNumber);
                              setLineSelection({ start, end });
                            } else {
                              setLineSelection({ start: lineNumber, end: lineNumber });
                            }

                            return true;
                          },
                          mouseover: (view, line, event) => {
                            if (!(event instanceof MouseEvent)) return false;
                            if (event.buttons !== 1) return false;
                            if (!isSelectingRef.current || selectionStartRef.current === null) return false;
                            const lineNumber = view.state.doc.lineAt(line.from).number;
                            const start = Math.min(selectionStartRef.current, lineNumber);
                            const end = Math.max(selectionStartRef.current, lineNumber);
                            setLineSelection({ start, end });
                            setIsDragging(true);
                            return false;
                          },
                          mouseup: () => {
                            isSelectingRef.current = false;
                            selectionStartRef.current = null;
                            setIsDragging(false);
                            return false;
                          },
                        },
                    }}
                  />
                </div>
                )}
              </div>
            </div>
          )}
        </ScrollableOverlay>
      </div>
    </div>
  );
};
