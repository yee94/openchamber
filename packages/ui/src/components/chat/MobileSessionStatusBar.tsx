import React from 'react';
import { useSessionUIStore } from '@/sync/session-ui-store';
import { useAllSessionStatuses, useAllLiveSessions } from '@/sync/sync-context';
import { mergeLiveSessionWithGlobalSession, useGlobalSessionsStore, refreshGlobalSessions } from '@/stores/useGlobalSessionsStore';
import { useUIStore } from '@/stores/useUIStore';
import { useProjectsStore } from '@/stores/useProjectsStore';
import { useSessionPinnedStore } from '@/stores/useSessionPinnedStore';
import type { Session } from '@opencode-ai/sdk/v2';
import type { ProjectEntry } from '@/lib/api/types';
import { cn, formatDirectoryName } from '@/lib/utils';
import { PROJECT_ICON_MAP, PROJECT_COLOR_MAP, ProjectIconImage } from '@/lib/projectMeta';
import { Icon } from "@/components/icon/Icon";
import { SessionBusyIndicator } from '@/components/session/SessionBusyIndicator';
import { useThemeSystem } from '@/contexts/useThemeSystem';
import { useNotificationStore } from '@/sync/notification-store';
import { useI18n } from '@/lib/i18n';
import { MobileOverlayPanel } from '@/components/ui/MobileOverlayPanel';

interface MobileSessionStatusBarProps {
  onSessionSwitch?: (sessionId: string) => void;
}

interface SessionWithStatus extends Session {
  _statusType?: 'busy' | 'retry' | 'idle';
  _hasRunningChildren?: boolean;
  _runningChildrenCount?: number;
  _childIndicators?: Array<{ session: Session; isRunning: boolean }>;
}

// Cross-project session source. Mirrors the dedicated MobileSessionsSheet:
// global sessions cover all directories (even unbootstrapped ones), while the
// live aggregate (`useAllLiveSessions`) surfaces fresher data and every
// bootstrapped directory. Merging both makes other projects' sessions appear.
function useAllProjectSessions(): Session[] {
  const liveSessions = useAllLiveSessions();
  const globalActiveSessions = useGlobalSessionsStore((state) => state.activeSessions);
  return React.useMemo(() => {
    const liveById = new Map(liveSessions.map((session) => [session.id, session]));
    const merged = globalActiveSessions.map((session) => {
      const liveSession = liveById.get(session.id);
      return liveSession ? mergeLiveSessionWithGlobalSession(liveSession, session) : session;
    });
    const seen = new Set(merged.map((session) => session.id));
    for (const session of liveSessions) {
      if (!seen.has(session.id)) merged.push(session);
    }
    return merged;
  }, [globalActiveSessions, liveSessions]);
}

const MAX_RECENT_SESSIONS = 25;
const PINNED_SESSION_FILTER_ID = '__pinned_sessions__';

// Normalize path for comparison
const normalize = (value: string): string => {
  if (!value) return '';
  const replaced = value.replace(/\\/g, '/');
  return replaced === '/' ? '/' : replaced.replace(/\/+$/, '');
};

// A session's directory, mirroring the store's canonical resolution.
const sessionDirectory = (session: Session): string => {
  const record = session as Session & {
    directory?: string | null;
    project?: { worktree?: string | null } | null;
  };
  return normalize(record.directory ?? record.project?.worktree ?? '');
};

// Prefix-match used to group a session under a project root or worktree.
const pathBelongsToRoot = (path: string, root: string): boolean => {
  const p = normalize(path);
  const r = normalize(root);
  return Boolean(p && r && (p === r || p.startsWith(`${r}/`)));
};

function useSessionGrouping(
  sessions: Session[],
  sessionStatus: Record<string, { type: string }> | undefined
) {
  const unseenCounts = useNotificationStore((s) => s.index.session.unseenCount);

  const parentChildMap = React.useMemo(() => {
    const map = new Map<string, Session[]>();
    const allIds = new Set(sessions.map((s) => s.id));

    sessions.forEach((session) => {
      const parentID = (session as { parentID?: string }).parentID;
      if (parentID && allIds.has(parentID)) {
        map.set(parentID, [...(map.get(parentID) || []), session]);
      }
    });
    return map;
  }, [sessions]);

  const getStatusType = React.useCallback((sessionId: string): 'busy' | 'retry' | 'idle' => {
    const status = sessionStatus?.[sessionId];
    if (status?.type === 'busy' || status?.type === 'retry') return status.type;
    return 'idle';
  }, [sessionStatus]);

  const hasRunningChildren = React.useCallback((sessionId: string): boolean => {
    const children = parentChildMap.get(sessionId) || [];
    return children.some((child) => getStatusType(child.id) !== 'idle');
  }, [parentChildMap, getStatusType]);

  const getRunningChildrenCount = React.useCallback((sessionId: string): number => {
    const children = parentChildMap.get(sessionId) || [];
    return children.filter((child) => getStatusType(child.id) !== 'idle').length;
  }, [parentChildMap, getStatusType]);

  const getChildIndicators = React.useCallback((sessionId: string): Array<{ session: Session; isRunning: boolean }> => {
    const children = parentChildMap.get(sessionId) || [];
    return children
      .filter((child) => getStatusType(child.id) !== 'idle')
      .map((child) => ({ session: child, isRunning: true }))
      .slice(0, 3);
  }, [parentChildMap, getStatusType]);

  const processedSessions = React.useMemo(() => {
    const sessionIds = new Set(sessions.map((s) => s.id));
    const topLevel = sessions.filter((session) => {
      const parentID = (session as { parentID?: string }).parentID;
      return !parentID || !sessionIds.has(parentID);
    });

    const running: SessionWithStatus[] = [];
    const viewed: SessionWithStatus[] = [];

    topLevel.forEach((session) => {
      const statusType = getStatusType(session.id);
      const hasRunning = hasRunningChildren(session.id);
      const attention = (unseenCounts[session.id] ?? 0) > 0;

      const enriched: SessionWithStatus = {
        ...session,
        _statusType: statusType,
        _hasRunningChildren: hasRunning,
        _runningChildrenCount: getRunningChildrenCount(session.id),
        _childIndicators: getChildIndicators(session.id),
      };

      if (statusType !== 'idle' || hasRunning) {
        running.push(enriched);
      } else if (attention) {
        running.push(enriched);
      } else {
        viewed.push(enriched);
      }
    });

    const sortByUpdated = (a: Session, b: Session) => {
      const aTime = (a as unknown as { time?: { updated?: number } }).time?.updated ?? 0;
      const bTime = (b as unknown as { time?: { updated?: number } }).time?.updated ?? 0;
      return bTime - aTime;
    };

    running.sort(sortByUpdated);
    viewed.sort(sortByUpdated);

    return [...running, ...viewed];
  }, [sessions, getStatusType, hasRunningChildren, getRunningChildrenCount, getChildIndicators, unseenCounts]);

  const totalRunning = processedSessions.reduce((sum, s) => {
    const selfRunning = s._statusType !== 'idle' ? 1 : 0;
    return sum + selfRunning + (s._runningChildrenCount ?? 0);
  }, 0);

  const totalUnread = processedSessions.filter((s) => (unseenCounts[s.id] ?? 0) > 0).length;

  return { sessions: processedSessions, totalRunning, totalUnread, totalCount: processedSessions.length };
}

function useSessionHelpers() {
  const { t } = useI18n();

  const getSessionTitle = React.useCallback((session: Session): string => {
    const title = session.title;
    if (title && title.trim()) return title;
    return t('mobile.sessions.newChat');
  }, [t]);

  const unseenCounts = useNotificationStore((s) => s.index.session.unseenCount);
  const needsAttention = React.useCallback((sessionId: string): boolean => {
    return (unseenCounts[sessionId] ?? 0) > 0;
  }, [unseenCounts]);

  return { getSessionTitle, needsAttention };
}

// Per-project status indicators (running / unread) for the filter chips.
function useProjectStatus(
  sessions: Session[],
  sessionStatus: Record<string, { type: string }> | undefined,
  currentSessionId: string | null
) {
  const availableWorktreesByProject = useSessionUIStore((state) => state.availableWorktreesByProject);
  const getSessionsByDirectory = useSessionUIStore((state) => state.getSessionsByDirectory);
  const notifUnseenCounts = useNotificationStore((s) => s.index.session.unseenCount);

  return React.useCallback((projectPath: string): { hasRunning: boolean; hasUnread: boolean } => {
    const getStatusType = (sessionId: string): 'busy' | 'retry' | 'idle' => {
      const status = sessionStatus?.[sessionId];
      if (status?.type === 'busy' || status?.type === 'retry') return status.type;
      return 'idle';
    };

    const projectRoot = normalize(projectPath);
    if (!projectRoot) return { hasRunning: false, hasUnread: false };

    const dirs: string[] = [projectRoot];
    const worktrees = availableWorktreesByProject.get(projectRoot) ?? [];
    for (const meta of worktrees) {
      const p = (meta && typeof meta === 'object' && 'path' in meta) ? (meta as { path?: unknown }).path : null;
      if (typeof p === 'string' && p.trim()) {
        const normalized = normalize(p);
        if (normalized && normalized !== projectRoot) dirs.push(normalized);
      }
    }

    const seen = new Set<string>();
    let hasRunning = false;
    let hasUnread = false;

    for (const dir of dirs) {
      for (const session of getSessionsByDirectory(dir)) {
        if (!session?.id || seen.has(session.id)) continue;
        seen.add(session.id);

        if (getStatusType(session.id) !== 'idle') hasRunning = true;
        if (session.id !== currentSessionId && (notifUnseenCounts[session.id] ?? 0) > 0) hasUnread = true;
        if (hasRunning && hasUnread) break;
      }
      if (hasRunning && hasUnread) break;
    }

    return { hasRunning, hasUnread };
  }, [getSessionsByDirectory, availableWorktreesByProject, sessionStatus, notifUnseenCounts, currentSessionId]);
}

// Resolves the project's root directories (root + known worktrees) for
// prefix-matching sessions, mirroring the dedicated MobileSessionsSheet.
function useProjectRootsResolver() {
  const availableWorktreesByProject = useSessionUIStore((state) => state.availableWorktreesByProject);

  return React.useCallback((project: ProjectEntry): string[] => {
    const projectRoot = normalize(project.path);
    const roots = [projectRoot];
    const worktrees = availableWorktreesByProject.get(projectRoot) ?? [];
    for (const meta of worktrees) {
      const p = (meta && typeof meta === 'object' && 'path' in meta) ? (meta as { path?: unknown }).path : null;
      if (typeof p === 'string' && p.trim()) {
        const normalized = normalize(p);
        if (normalized) roots.push(normalized);
      }
    }
    return roots;
  }, [availableWorktreesByProject]);
}

function StatusIndicator({ isRunning, showUnread }: { isRunning: boolean; showUnread: boolean }) {
  if (isRunning) {
    return <SessionBusyIndicator />;
  }
  if (showUnread) {
    return <div className="h-2 w-2 rounded-full bg-[var(--status-info)]" />;
  }
  return null;
}

function RunningIndicator({ count }: { count: number }) {
  if (count === 0) return null;
  return (
    <span className="flex items-center gap-1 text-[13px] text-[var(--surface-mutedForeground)]">
      <SessionBusyIndicator />
      {count}
    </span>
  );
}

function UnreadIndicator({ count }: { count: number }) {
  if (count === 0) return null;
  return (
    <span className="flex items-center gap-1 text-[13px] text-[var(--status-info)]">
      <div className="h-2 w-2 rounded-full bg-[var(--status-info)]" />
      {count}
    </span>
  );
}

// A single session row sized for comfortable touch.
function SessionItem({
  session,
  isCurrent,
  getSessionTitle,
  onClick,
  needsAttention,
}: {
  session: SessionWithStatus;
  isCurrent: boolean;
  getSessionTitle: (s: Session) => string;
  onClick: () => void;
  needsAttention: (sessionId: string) => boolean;
}) {
  const attention = needsAttention(session.id);

  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left transition-colors min-h-[56px]",
        "active:bg-[var(--interactive-selection)]",
        isCurrent ? "bg-[color-mix(in_srgb,var(--interactive-selection)_40%,transparent)]" : "hover:bg-[var(--interactive-hover)]"
      )}
    >
      <span className="flex h-4 w-4 flex-shrink-0 items-center justify-center">
        <StatusIndicator
          isRunning={session._statusType !== 'idle'}
          showUnread={attention && !isCurrent}
        />
      </span>

      <span className={cn(
        "flex-1 truncate text-[15px] leading-tight",
        isCurrent ? "font-semibold text-[var(--surface-foreground)]" : "text-[var(--surface-foreground)]"
      )}>
        {getSessionTitle(session)}
      </span>

      {(session._runningChildrenCount ?? 0) > 0 && (
        <span className="flex flex-shrink-0 items-center gap-1 text-[12px] text-[var(--surface-mutedForeground)]">
          <SessionBusyIndicator size={12} />
          {session._runningChildrenCount}
        </span>
      )}

      {isCurrent && (
        <Icon name="check" className="h-4 w-4 flex-shrink-0 text-[var(--primary-base)]" />
      )}
    </button>
  );
}

// A project filter pill sized for touch. Selecting it filters
// the session list; it does NOT switch the active project.
interface ProjectFilterChipProps {
  label: string;
  leadingIcon?: React.ReactNode;
  icon?: string | null;
  project?: Pick<ProjectEntry, 'id' | 'iconImage'> | null;
  iconOptions?: React.ComponentProps<typeof ProjectIconImage>['options'];
  iconBackground?: string | null;
  colorVar?: string | null;
  isActive: boolean;
  status?: { hasRunning: boolean; hasUnread: boolean };
  onClick: () => void;
}

function ProjectFilterChip({
  label,
  leadingIcon,
  icon,
  project,
  iconOptions,
  iconBackground,
  colorVar,
  isActive,
  status,
  onClick,
}: ProjectFilterChipProps) {
  const projectIconName = icon ? PROJECT_ICON_MAP[icon] : null;
  const fallbackIcon = projectIconName ? (
    <Icon name={projectIconName} className="h-4 w-4" style={!isActive && colorVar ? { color: colorVar } : undefined} />
  ) : null;

  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "flex min-h-[40px] shrink-0 select-none items-center gap-1.5 rounded-full border px-3.5 text-[13px] leading-none whitespace-nowrap transition-colors",
        isActive
          ? "border-transparent bg-[var(--primary-base)] text-[var(--primary-foreground)] font-medium"
          : "border-[var(--interactive-border)] bg-[var(--surface-subtle)] text-[var(--surface-foreground)] active:bg-[var(--interactive-hover)]"
      )}
    >
      {leadingIcon}
      {status && (status.hasRunning || status.hasUnread) && !isActive && (
        status.hasRunning
          ? <SessionBusyIndicator size={10} />
          : <span className="h-1.5 w-1.5 rounded-full bg-[var(--status-info)]" />
      )}

      {project?.iconImage ? (
        <span
          className="inline-flex h-4 w-4 items-center justify-center overflow-hidden rounded-[2px]"
          style={iconBackground ? { backgroundColor: iconBackground } : undefined}
        >
          <ProjectIconImage
            project={project}
            options={iconOptions}
            className="h-full w-full object-contain"
            fallback={fallbackIcon}
          />
        </span>
      ) : fallbackIcon}

      <span className="max-w-[140px] truncate">{label}</span>
    </button>
  );
}

export const MobileSessionStatusBar: React.FC<MobileSessionStatusBarProps> = ({
  onSessionSwitch,
}) => {
  const { t } = useI18n();
  const { currentTheme } = useThemeSystem();
  const isMobile = useUIStore((state) => state.isMobile);
  const sessions = useAllProjectSessions();
  const currentSessionId = useSessionUIStore((state) => state.currentSessionId);
  const sessionStatus = useAllSessionStatuses();
  const setCurrentSession = useSessionUIStore((state) => state.setCurrentSession);
  const openNewSessionDraft = useSessionUIStore((state) => state.openNewSessionDraft);
  const open = useUIStore((state) => state.mobileSessionPanelOpen);
  const setOpen = useUIStore((state) => state.setMobileSessionPanelOpen);

  const projects = useProjectsStore((state) => state.projects);
  const pinnedSessionIds = useSessionPinnedStore((state) => state.ids);

  const { sessions: sortedSessions, totalRunning, totalUnread } = useSessionGrouping(sessions, sessionStatus);
  const { getSessionTitle, needsAttention } = useSessionHelpers();
  const getProjectStatus = useProjectStatus(sessions, sessionStatus, currentSessionId);
  const resolveProjectRoots = useProjectRootsResolver();

  // Project filter persists across sheet openings. The pinned sentinel shares
  // the same state slot because it is a list scope alongside project scopes.
  const filterProjectId = useUIStore((state) => state.mobileSessionFilterProjectId);
  const setFilterProjectId = useUIStore((state) => state.setMobileSessionFilterProjectId);
  const hasPinnedSessions = React.useMemo(
    () => sortedSessions.some((session) => pinnedSessionIds.has(session.id)),
    [pinnedSessionIds, sortedSessions],
  );

  React.useEffect(() => {
    if (!hasPinnedSessions && filterProjectId === PINNED_SESSION_FILTER_ID) {
      setFilterProjectId(null);
    }
  }, [filterProjectId, hasPinnedSessions, setFilterProjectId]);

  // Refresh the cross-project session list when the panel opens (mirrors the
  // dedicated MobileSessionsSheet). The active-directory sync only upserts the
  // current project's sessions, so other projects need this global load.
  React.useEffect(() => {
    if (open) {
      void refreshGlobalSessions(sessions);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  const formatProjectLabel = React.useCallback((project: ProjectEntry): string => {
    return formatDirectoryName(project.path) || project.path;
  }, []);

  // Filter sessions by the selected project (root + worktrees), using the
  // store's canonical directory keying.
  const filteredSessions = React.useMemo(() => {
    if (!filterProjectId) return sortedSessions;
    if (filterProjectId === PINNED_SESSION_FILTER_ID) {
      return sortedSessions.filter((session) => pinnedSessionIds.has(session.id));
    }
    const project = projects.find((p) => p.id === filterProjectId);
    if (!project) return sortedSessions;
    const roots = resolveProjectRoots(project);
    return sortedSessions.filter((session) => {
      const dir = sessionDirectory(session);
      return roots.some((root) => pathBelongsToRoot(dir, root));
    });
  }, [sortedSessions, filterProjectId, pinnedSessionIds, projects, resolveProjectRoots]);

  // The All and Pinned scopes expose their complete result sets. Project scopes
  // retain the compact mobile cap.
  const visibleSessions = React.useMemo(
    () => filterProjectId === null || filterProjectId === PINNED_SESSION_FILTER_ID
      ? filteredSessions
      : filteredSessions.slice(0, MAX_RECENT_SESSIONS),
    [filterProjectId, filteredSessions],
  );

  const handleSessionClick = (session: SessionWithStatus) => {
    setCurrentSession(session.id, sessionDirectory(session) || null);
    onSessionSwitch?.(session.id);
    setOpen(false);
  };

  // "+" — start a new session draft. Target the project selected in the filter;
  // for "All", use the most recently active session's directory, falling back to
  // the store's own default target when there are no sessions.
  const handleNewChat = React.useCallback(() => {
    setOpen(false);
    if (filterProjectId) {
      const project = projects.find((p) => p.id === filterProjectId);
      if (project) {
        openNewSessionDraft({ selectedProjectId: project.id, directoryOverride: project.path });
        return;
      }
    }
    const mostRecent = [...sessions].sort((a, b) => {
      const aTime = (a as { time?: { updated?: number } }).time?.updated ?? 0;
      const bTime = (b as { time?: { updated?: number } }).time?.updated ?? 0;
      return bTime - aTime;
    })[0];
    const directory = mostRecent ? sessionDirectory(mostRecent) : '';
    openNewSessionDraft(directory ? { directoryOverride: directory } : undefined);
  }, [filterProjectId, projects, sessions, openNewSessionDraft, setOpen]);

  const renderHeader = React.useCallback(() => (
    <div className="shrink-0">
      <div className="flex justify-center pt-2.5 pb-1">
        <div className="h-1 w-9 rounded-full bg-[color-mix(in_srgb,var(--surface-mutedForeground)_40%,transparent)]" />
      </div>

      <div className="flex items-center justify-between gap-2 px-4 pb-2">
        <h2 className="text-[16px] font-semibold text-[var(--surface-foreground)]">
          {t('mobile.sessions.search.section.sessions')}
        </h2>
        <div className="flex items-center gap-3">
          <RunningIndicator count={totalRunning} />
          <UnreadIndicator count={totalUnread} />
          <button
            type="button"
            onClick={handleNewChat}
            aria-label={t('mobile.sessions.newChat')}
            className="flex size-8 items-center justify-center rounded-full text-[var(--surface-mutedForeground)] transition-colors hover:bg-[var(--interactive-hover)] hover:text-[var(--surface-foreground)]"
            style={{ touchAction: 'manipulation' }}
          >
            <Icon name="add" className="h-5 w-5" />
          </button>
          <button
            type="button"
            onClick={() => setOpen(false)}
            className="flex size-8 items-center justify-center rounded-full text-[var(--surface-mutedForeground)] transition-colors hover:bg-[var(--interactive-hover)] hover:text-[var(--surface-foreground)]"
            style={{ touchAction: 'manipulation' }}
          >
            <Icon name="close" className="h-5 w-5" />
          </button>
        </div>
      </div>

      {(projects.length > 1 || hasPinnedSessions) && (
        <div
          className="flex items-center gap-2 overflow-x-auto border-t border-[color-mix(in_srgb,var(--interactive-border)_40%,transparent)] px-4 py-2.5 scrollbar-none"
          style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
        >
          <ProjectFilterChip
            label={t('chat.modelControls.modeValue.all')}
            isActive={filterProjectId === null}
            onClick={() => setFilterProjectId(null)}
          />
          {hasPinnedSessions ? (
            <ProjectFilterChip
              label={t('sessions.sidebar.session.actions.pinned')}
              leadingIcon={<Icon name="pushpin-2-fill" className="size-3.5" />}
              isActive={filterProjectId === PINNED_SESSION_FILTER_ID}
              onClick={() => setFilterProjectId(PINNED_SESSION_FILTER_ID)}
            />
          ) : null}
          {projects.map((project) => (
            <ProjectFilterChip
              key={project.id}
              label={formatProjectLabel(project)}
              icon={project.icon}
              project={{ id: project.id, iconImage: project.iconImage ?? null }}
              iconOptions={{
                themeVariant: currentTheme.metadata.variant,
                iconColor: currentTheme.colors.surface.foreground,
              }}
              iconBackground={project.iconBackground ?? null}
              colorVar={project.color ? (PROJECT_COLOR_MAP[project.color] ?? null) : null}
              isActive={filterProjectId === project.id}
              status={getProjectStatus(project.path)}
              onClick={() => setFilterProjectId(project.id)}
            />
          ))}
        </div>
      )}
    </div>
  ), [t, totalRunning, totalUnread, projects, hasPinnedSessions, filterProjectId, setFilterProjectId, formatProjectLabel, currentTheme, getProjectStatus, handleNewChat, setOpen]);

  if (!isMobile) {
    return null;
  }

  return (
    <MobileOverlayPanel
      open={open}
      onClose={() => setOpen(false)}
      title={t('mobile.sessions.search.section.sessions')}
      renderHeader={renderHeader}
      className="h-[72vh]"
      contentMaxHeightClassName="max-h-full"
    >
      <div className="flex min-h-full flex-col gap-0.5">
        {visibleSessions.length === 0 ? (
          <div className="flex flex-1 items-center justify-center py-10 text-[13px] text-[var(--surface-mutedForeground)]">
            <span>{t('chat.mobileStatus.noSessionsInProject')}</span>
          </div>
        ) : (
          visibleSessions.map((session) => (
            <SessionItem
              key={session.id}
              session={session}
              isCurrent={session.id === currentSessionId}
              getSessionTitle={getSessionTitle}
              onClick={() => handleSessionClick(session)}
              needsAttention={needsAttention}
            />
          ))
        )}
      </div>
    </MobileOverlayPanel>
  );
};
