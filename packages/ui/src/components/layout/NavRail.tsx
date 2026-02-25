import React from 'react';
import {
  DndContext,
  closestCenter,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
  type Modifier,
} from '@dnd-kit/core';
import {
  SortableContext,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import {
  RiFolderAddLine,
  RiSettings3Line,
  RiQuestionLine,
  RiDownloadLine,
  RiInformationLine,
  RiPencilLine,
  RiCloseLine,
} from '@remixicon/react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { toast } from '@/components/ui';

import { UpdateDialog } from '@/components/ui/UpdateDialog';
import { ProjectEditDialog } from '@/components/layout/ProjectEditDialog';
import { useUIStore } from '@/stores/useUIStore';
import { useProjectsStore } from '@/stores/useProjectsStore';
import { useSessionStore } from '@/stores/useSessionStore';
import { useDirectoryStore } from '@/stores/useDirectoryStore';
import { useUpdateStore } from '@/stores/useUpdateStore';
import { cn, formatDirectoryName, hasModifier } from '@/lib/utils';
import { PROJECT_ICON_MAP, PROJECT_COLOR_MAP } from '@/lib/projectMeta';
import { isDesktopLocalOriginActive, isDesktopShell, isTauriShell } from '@/lib/desktop';
import { useLongPress } from '@/hooks/useLongPress';
import { sessionEvents } from '@/lib/sessionEvents';
import type { ProjectEntry } from '@/lib/api/types';

const normalize = (value: string): string => {
  if (!value) return '';
  const replaced = value.replace(/\\/g, '/');
  return replaced === '/' ? '/' : replaced.replace(/\/+$/, '');
};

const NAV_RAIL_WIDTH = 56;

/** Tinted background for project tiles — uses project color at low opacity, or neutral fallback */
const TileBackground: React.FC<{ colorVar: string | null; children: React.ReactNode }> = ({
  colorVar,
  children,
}) => (
  <span
    className="relative flex h-full w-full items-center justify-center rounded-lg overflow-hidden"
    style={{ backgroundColor: 'var(--surface-muted)' }}
  >
    {colorVar && (
      <span
        className="absolute inset-0 opacity-15"
        style={{ backgroundColor: colorVar }}
      />
    )}
    <span className="relative z-10 flex items-center justify-center">
      {children}
    </span>
  </span>
);

/** First-letter avatar fallback */
const LetterAvatar: React.FC<{ label: string; color?: string | null }> = ({
  label,
  color,
}) => {
  const letter = label.charAt(0).toUpperCase() || '?';
  const colorVar = color ? (PROJECT_COLOR_MAP[color] ?? null) : null;
  return (
    <span
      className="flex h-4 w-4 items-center justify-center text-[15px] font-medium leading-none select-none"
      style={{ color: colorVar ?? 'var(--surface-foreground)', fontFamily: 'var(--font-mono, monospace)' }}
    >
      {letter}
    </span>
  );
};

const ProjectStatusDots: React.FC<{
  color: string;
  variant?: 'streaming' | 'attention' | 'none';
  size?: 'sm' | 'md';
}> = ({ color, variant = 'none', size = 'md' }) => (
  <span className="inline-flex items-center justify-center gap-px" aria-hidden="true">
    {Array.from({ length: 3 }).map((_, index) => (
      <span key={index} className="inline-flex h-[3px] w-[3px] items-center justify-center">
        <span
          className={cn(
            size === 'sm' ? 'h-[2.5px] w-[2.5px]' : 'h-[3px] w-[3px]',
            'rounded-full',
            variant === 'streaming' && 'animate-grid-pulse',
            variant === 'attention' && 'animate-attention-diamond-pulse'
          )}
          style={{
            backgroundColor: color,
            animationDelay: variant === 'streaming'
              ? `${index * 150}ms`
              : variant === 'attention'
                ? (index === 1 ? '0ms' : '130ms')
                : undefined,
          }}
        />
      </span>
    ))}
  </span>
);

/** Single project tile in the nav rail — right-click for context menu (no visible 3-dot) */
const ProjectTile: React.FC<{
  project: ProjectEntry;
  isActive: boolean;
  hasStreaming: boolean;
  hasUnread: boolean;
  label: string;
  onClick: () => void;
  onEdit: () => void;
  onClose: () => void;
}> = ({ project, isActive, hasStreaming, hasUnread, label, onClick, onEdit, onClose }) => {
  const [menuOpen, setMenuOpen] = React.useState(false);
  const ProjectIcon = project.icon ? PROJECT_ICON_MAP[project.icon] : null;
  const projectColorVar = project.color ? (PROJECT_COLOR_MAP[project.color] ?? null) : null;
  const showStreamingDots = hasStreaming;
  const showAttentionDots = !hasStreaming && hasUnread;

  const longPressHandlers = useLongPress({
    onLongPress: () => setMenuOpen(true),
    onTap: onClick,
  });

  return (
    <>
    <Tooltip delayDuration={400}>
      <TooltipTrigger asChild>
        <div
          className="relative"
          onContextMenu={(e) => {
            // Only handle right-click (desktop), not long-tap (mobile)
            if (e.nativeEvent instanceof MouseEvent && e.nativeEvent.button === 2) {
              e.preventDefault();
              setMenuOpen(true);
            }
          }}
        >
          {hasStreaming ? (
            <button
              type="button"
              {...longPressHandlers}
              className={cn(
                'flex h-9 w-9 items-center justify-center rounded-lg overflow-hidden cursor-default',
                isActive
                  ? 'bg-transparent border border-[var(--surface-foreground)]'
                  : 'bg-transparent border border-transparent hover:bg-[var(--interactive-hover)]/50 hover:border-[var(--interactive-border)]',
                menuOpen && !isActive && 'bg-[var(--interactive-hover)]/50 border-[var(--interactive-border)]',
                'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--interactive-focus-ring)]',
              )}
              >
                <TileBackground colorVar={projectColorVar}>
                  <span className="relative h-full w-full leading-none">
                    <span className="pointer-events-none absolute inset-0 flex items-center justify-center">
                      {ProjectIcon ? (
                        <ProjectIcon
                          className="h-4 w-4 shrink-0"
                          style={projectColorVar ? { color: projectColorVar } : { color: 'var(--surface-foreground)' }}
                        />
                      ) : (
                        <LetterAvatar label={label} color={project.color} />
                      )}
                    </span>
                    {showStreamingDots && (
                      <span className="pointer-events-none absolute inset-x-0 top-[calc(50%+9px)] flex justify-center">
                        <ProjectStatusDots color="var(--primary)" variant="streaming" />
                      </span>
                    )}
                  </span>
                </TileBackground>
              </button>
            ) : (
            <button
              type="button"
              {...longPressHandlers}
              className={cn(
                'flex h-9 w-9 items-center justify-center rounded-lg overflow-hidden cursor-default',
                'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--interactive-focus-ring)]',
                isActive
                  ? 'bg-transparent border border-[var(--surface-foreground)]'
                  : 'bg-transparent border border-transparent hover:bg-[var(--interactive-hover)]/50 hover:border-[var(--interactive-border)]',
                menuOpen && !isActive && 'bg-[var(--interactive-hover)]/50 border-[var(--interactive-border)]',
              )}
            >
              <TileBackground colorVar={projectColorVar}>
                <span className="relative h-full w-full leading-none">
                  <span className="pointer-events-none absolute inset-0 flex items-center justify-center">
                    {ProjectIcon ? (
                      <ProjectIcon
                        className="h-4 w-4 shrink-0"
                        style={projectColorVar ? { color: projectColorVar } : { color: 'var(--surface-foreground)' }}
                      />
                    ) : (
                        <LetterAvatar label={label} color={project.color} />
                    )}
                  </span>
                  {showAttentionDots && (
                    <span className="pointer-events-none absolute inset-x-0 top-[calc(50%+9px)] flex justify-center">
                      <ProjectStatusDots color="var(--status-info)" variant="attention" />
                    </span>
                  )}
                </span>
              </TileBackground>
            </button>
          )}

        </div>
      </TooltipTrigger>
      <TooltipContent side="right" sideOffset={8}>
        {label}
      </TooltipContent>
    </Tooltip>
    <DropdownMenu open={menuOpen} onOpenChange={setMenuOpen}>
      <DropdownMenuTrigger asChild>
        <span className="sr-only">Project options</span>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" side="right" sideOffset={4} className="min-w-[160px]">
        <DropdownMenuItem onClick={onEdit} className="gap-2">
          <RiPencilLine className="h-4 w-4" />
          Edit project
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem
          onClick={onClose}
          className="text-destructive focus:text-destructive gap-2"
        >
          <RiCloseLine className="h-4 w-4" />
          Close project
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
    </>
  );
};

/** Constrain drag to Y axis only */
const restrictToYAxis: Modifier = ({ transform }) => ({
  ...transform,
  x: 0,
});

/** Sortable wrapper for ProjectTile */
const SortableProjectTile: React.FC<{
  id: string;
  children: React.ReactNode;
}> = ({ id, children }) => {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id });

  return (
    <div
      ref={setNodeRef}
      style={{
        transform: CSS.Transform.toString(transform),
        transition,
      }}
      className={cn(isDragging && 'opacity-30 z-50')}
      {...attributes}
      {...listeners}
    >
      {children}
    </div>
  );
};

interface NavRailProps {
  className?: string;
  mobile?: boolean;
}

export const NavRail: React.FC<NavRailProps> = ({ className, mobile }) => {
  const projects = useProjectsStore((s) => s.projects);
  const activeProjectId = useProjectsStore((s) => s.activeProjectId);
  const setActiveProjectIdOnly = useProjectsStore((s) => s.setActiveProjectIdOnly);
  const addProject = useProjectsStore((s) => s.addProject);
  const removeProject = useProjectsStore((s) => s.removeProject);
  const reorderProjects = useProjectsStore((s) => s.reorderProjects);
  const updateProjectMeta = useProjectsStore((s) => s.updateProjectMeta);
  const homeDirectory = useDirectoryStore((s) => s.homeDirectory);
  const setSettingsDialogOpen = useUIStore((s) => s.setSettingsDialogOpen);
  const setAboutDialogOpen = useUIStore((s) => s.setAboutDialogOpen);
  const toggleHelpDialog = useUIStore((s) => s.toggleHelpDialog);

  const sessionStatus = useSessionStore((s) => s.sessionStatus);
  const sessionAttentionStates = useSessionStore((s) => s.sessionAttentionStates);
  const sessionsByDirectory = useSessionStore((s) => s.sessionsByDirectory);
  const getSessionsByDirectory = useSessionStore((s) => s.getSessionsByDirectory);
  const currentSessionId = useSessionStore((s) => s.currentSessionId);
  const availableWorktreesByProject = useSessionStore((s) => s.availableWorktreesByProject);

  const updateStore = useUpdateStore();
  const { available: updateAvailable, downloaded: updateDownloaded } = updateStore;
  const [updateDialogOpen, setUpdateDialogOpen] = React.useState(false);

  const [editingProject, setEditingProject] = React.useState<{
    id: string;
    name: string;
    path: string;
    icon?: string | null;
    color?: string | null;
  } | null>(null);

  const isDesktopApp = React.useMemo(() => isDesktopShell(), []);
  const tauriIpcAvailable = React.useMemo(() => isTauriShell(), []);

  const formatLabel = React.useCallback(
    (project: ProjectEntry): string => {
      return (
        project.label?.trim() ||
        formatDirectoryName(project.path, homeDirectory) ||
        project.path
      );
    },
    [homeDirectory],
  );

  const projectIndicators = React.useMemo(() => {
    const result = new Map<string, { hasStreaming: boolean; hasUnread: boolean }>();
    for (const project of projects) {
      const projectRoot = normalize(project.path);
      if (!projectRoot) {
        result.set(project.id, { hasStreaming: false, hasUnread: false });
        continue;
      }

      const dirs: string[] = [projectRoot];
      const worktrees = availableWorktreesByProject.get(projectRoot) ?? [];
      for (const meta of worktrees) {
        const p =
          meta && typeof meta === 'object' && 'path' in meta
            ? (meta as { path?: unknown }).path
            : null;
        if (typeof p === 'string' && p.trim()) {
          const normalized = normalize(p);
          if (normalized && normalized !== projectRoot) {
            dirs.push(normalized);
          }
        }
      }

      const seen = new Set<string>();
      let hasStreaming = false;
      let hasUnread = false;

      for (const dir of dirs) {
        const list = sessionsByDirectory.get(dir) ?? getSessionsByDirectory(dir);
        for (const session of list) {
          if (!session?.id || seen.has(session.id)) continue;
          seen.add(session.id);

          const statusType = sessionStatus?.get(session.id)?.type ?? 'idle';
          if (statusType === 'busy' || statusType === 'retry') {
            hasStreaming = true;
          }

          const isCurrentVisible =
            session.id === currentSessionId && project.id === activeProjectId;
          if (
            !isCurrentVisible &&
            sessionAttentionStates.get(session.id)?.needsAttention === true
          ) {
            hasUnread = true;
          }

          if (hasStreaming && hasUnread) break;
        }
        if (hasStreaming && hasUnread) break;
      }

      result.set(project.id, { hasStreaming, hasUnread });
    }
    return result;
  }, [
    activeProjectId,
    availableWorktreesByProject,
    currentSessionId,
    getSessionsByDirectory,
    projects,
    sessionAttentionStates,
    sessionStatus,
    sessionsByDirectory,
  ]);

  const handleAddProject = React.useCallback(() => {
    if (!tauriIpcAvailable || !isDesktopLocalOriginActive()) {
      sessionEvents.requestDirectoryDialog();
      return;
    }
    import('@/lib/desktop')
      .then(({ requestDirectoryAccess }) => requestDirectoryAccess(''))
      .then((result) => {
        if (result.success && result.path) {
          const added = addProject(result.path, { id: result.projectId });
          if (!added) {
            toast.error('Failed to add project', {
              description: 'Please select a valid directory.',
            });
          }
        } else if (result.error && result.error !== 'Directory selection cancelled') {
          toast.error('Failed to select directory', { description: result.error });
        }
      })
      .catch((error) => {
        console.error('Failed to select directory:', error);
        toast.error('Failed to select directory');
      });
  }, [addProject, tauriIpcAvailable]);

  const handleEditProject = React.useCallback(
    (projectId: string) => {
      const project = projects.find((p) => p.id === projectId);
      if (!project) return;
      setEditingProject({
        id: project.id,
        name: formatLabel(project),
        path: project.path,
        icon: project.icon,
        color: project.color,
      });
    },
    [projects, formatLabel],
  );

  const handleSaveProjectEdit = React.useCallback(
    (data: { label: string; icon: string | null; color: string | null }) => {
      if (!editingProject) return;
      updateProjectMeta(editingProject.id, data);
      setEditingProject(null);
    },
    [editingProject, updateProjectMeta],
  );

  const handleCloseProject = React.useCallback(
    (projectId: string) => {
      removeProject(projectId);
    },
    [removeProject],
  );

  // Cmd/Ctrl+number to switch projects
  React.useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (hasModifier(e) && !e.shiftKey && !e.altKey) {
        const num = parseInt(e.key, 10);
        if (num >= 1 && num <= projects.length) {
          e.preventDefault();
          const target = projects[num - 1];
          if (target && target.id !== activeProjectId) {
            setActiveProjectIdOnly(target.id);
          }
        }
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [projects, activeProjectId, setActiveProjectIdOnly]);

  // Drag-to-reorder
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
  );

  const projectIds = React.useMemo(() => projects.map((p) => p.id), [projects]);

  const handleDragEnd = React.useCallback(
    (event: DragEndEvent) => {
      const { active, over } = event;
      if (!over || active.id === over.id) return;
      const fromIndex = projects.findIndex((p) => p.id === active.id);
      const toIndex = projects.findIndex((p) => p.id === over.id);
      if (fromIndex !== -1 && toIndex !== -1) {
        reorderProjects(fromIndex, toIndex);
      }
    },
    [projects, reorderProjects],
  );

  const navRailActionButtonClass = cn(
    'flex h-8 w-8 items-center justify-center rounded-lg',
    'text-foreground hover:bg-interactive-hover',
    'transition-colors',
    'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--interactive-focus-ring)]',
  );

  const navRailActionIconClass = 'h-4.5 w-4.5';

  return (
    <>
      <nav
        className={cn(
          'flex h-full w-14 shrink-0 flex-col items-center bg-[var(--surface-background)] overflow-hidden',
          className,
        )}
        aria-label="Project navigation"
      >
        {/* Projects list */}
        <div className="flex-1 min-h-0 w-full overflow-y-auto overflow-x-hidden scrollbar-none">
          <DndContext
            sensors={sensors}
            collisionDetection={closestCenter}
            onDragEnd={handleDragEnd}
            modifiers={[restrictToYAxis]}
          >
          <SortableContext items={projectIds} strategy={verticalListSortingStrategy}>
          <div className="flex flex-col items-center gap-3 px-1 py-3">
            {projects.map((project) => {
              const isActive = project.id === activeProjectId;
              const indicators = projectIndicators.get(project.id);
              return (
                <SortableProjectTile key={project.id} id={project.id}>
                  <ProjectTile
                    project={project}
                    isActive={isActive}
                    hasStreaming={indicators?.hasStreaming ?? false}
                    hasUnread={indicators?.hasUnread ?? false}
                    label={formatLabel(project)}
                    onClick={() => {
                      if (project.id !== activeProjectId) {
                        setActiveProjectIdOnly(project.id);
                      }
                    }}
                    onEdit={() => handleEditProject(project.id)}
                    onClose={() => handleCloseProject(project.id)}
                  />
                </SortableProjectTile>
              );
            })}

          </div>
          </SortableContext>
          </DndContext>

            {/* Add project button */}
            <div className="flex flex-col items-center px-1 pb-3">
            <Tooltip delayDuration={400}>
              <TooltipTrigger asChild>
                <button
                  type="button"
                  onClick={handleAddProject}
                  className={navRailActionButtonClass}
                  aria-label="Add project"
                >
                  <RiFolderAddLine className={navRailActionIconClass} />
                </button>
              </TooltipTrigger>
              <TooltipContent side="right" sideOffset={8}>
                Add project
              </TooltipContent>
            </Tooltip>
            </div>
        </div>

        {/* Bottom actions */}
        <div className="shrink-0 w-full pt-3 pb-4 flex flex-col items-center gap-2">
          {(updateAvailable || updateDownloaded) && (
            <Tooltip delayDuration={400}>
              <TooltipTrigger asChild>
                <button
                  type="button"
                  onClick={() => setUpdateDialogOpen(true)}
                  className={cn(
                    'flex h-8 w-8 items-center justify-center rounded-lg',
                    'bg-[var(--primary)]/10 text-[var(--primary)]',
                    'hover:bg-[var(--primary)]/20 transition-colors',
                  )}
                  aria-label="Update available"
                >
                  <RiDownloadLine className={navRailActionIconClass} />
                </button>
              </TooltipTrigger>
              <TooltipContent side="right" sideOffset={8}>
                Update available
              </TooltipContent>
            </Tooltip>
          )}

          {!isDesktopApp && !(updateAvailable || updateDownloaded) && (
            <Tooltip delayDuration={400}>
              <TooltipTrigger asChild>
                <button
                  type="button"
                  onClick={() => setAboutDialogOpen(true)}
                  className={navRailActionButtonClass}
                  aria-label="About"
                >
                  <RiInformationLine className={navRailActionIconClass} />
                </button>
              </TooltipTrigger>
              <TooltipContent side="right" sideOffset={8}>
                About OpenChamber
              </TooltipContent>
            </Tooltip>
          )}

          {!mobile && (
            <Tooltip delayDuration={400}>
              <TooltipTrigger asChild>
                <button
                  type="button"
                  onClick={toggleHelpDialog}
                  className={navRailActionButtonClass}
                  aria-label="Keyboard shortcuts"
                >
                  <RiQuestionLine className={navRailActionIconClass} />
                </button>
              </TooltipTrigger>
              <TooltipContent side="right" sideOffset={8}>
                Keyboard shortcuts
              </TooltipContent>
            </Tooltip>
          )}

          <Tooltip delayDuration={400}>
            <TooltipTrigger asChild>
              <button
                type="button"
                onClick={() => setSettingsDialogOpen(true)}
                className={navRailActionButtonClass}
                aria-label="Settings"
              >
                <RiSettings3Line className={navRailActionIconClass} />
              </button>
            </TooltipTrigger>
            <TooltipContent side="right" sideOffset={8}>
              Settings
            </TooltipContent>
          </Tooltip>
        </div>
      </nav>

      {/* Dialogs */}
      {editingProject && (
        <ProjectEditDialog
          open={!!editingProject}
          onOpenChange={(open) => {
            if (!open) setEditingProject(null);
          }}
          projectName={editingProject.name}
          projectPath={editingProject.path}
          initialIcon={editingProject.icon}
          initialColor={editingProject.color}
          onSave={handleSaveProjectEdit}
        />
      )}

      <UpdateDialog
        open={updateDialogOpen}
        onOpenChange={setUpdateDialogOpen}
        info={updateStore.info}
        downloading={updateStore.downloading}
        downloaded={updateStore.downloaded}
        progress={updateStore.progress}
        error={updateStore.error}
        onDownload={updateStore.downloadUpdate}
        onRestart={updateStore.restartToUpdate}
        runtimeType={updateStore.runtimeType}
      />
    </>
  );
};

export { NAV_RAIL_WIDTH };
