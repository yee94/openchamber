import React from "react";
import { useSessionUIStore } from '@/sync/session-ui-store';
import { cn } from "@/lib/utils";
import { useDirectorySync } from "@/sync/sync-context";
import type { Todo } from "@opencode-ai/sdk/v2/client";

// Compat aliases for old TodoItem shape
type TodoItem = Todo & { id?: string };
type TodoStatus = string;
import { useUIStore } from "@/stores/useUIStore";
import { useTodosPersistStore } from "@/stores/useTodosPersistStore";
import { WorkingPlaceholder } from "./message/parts/WorkingPlaceholder";
import { isVSCodeRuntime } from "@/lib/desktop";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { Icon } from "@/components/icon/Icon";
import { useI18n } from "@/lib/i18n";

const STATUS_ROW_CONTAINER_STYLE = { containerType: "inline-size" as const, containerName: "status-row" };

const statusConfig: Record<TodoStatus, { textClassName: string }> = {
  in_progress: {
    textClassName: "text-foreground",
  },
  pending: {
    textClassName: "text-foreground",
  },
  completed: {
    textClassName: "text-muted-foreground line-through",
  },
  cancelled: {
    textClassName: "text-muted-foreground line-through",
  },
};

const statusLabelKey: Record<TodoStatus, string> = {
  in_progress: "chat.statusRow.todo.status.inProgress",
  pending: "chat.statusRow.todo.status.pending",
  completed: "chat.statusRow.todo.status.completed",
  cancelled: "chat.statusRow.todo.status.cancelled",
};

interface TodoItemRowProps {
  todo: TodoItem;
  isActive: boolean;
  activeRef?: React.Ref<HTMLLIElement>;
}

const TodoItemRow: React.FC<TodoItemRowProps> = ({ todo, isActive, activeRef }) => {
  const { t } = useI18n();
  const config = statusConfig[todo.status] || statusConfig.pending;
  const statusKey = statusLabelKey[todo.status] ?? statusLabelKey.pending;

  const statusIcon =
    todo.status === "in_progress" ? (
      <Icon name="record-circle" className="h-3.5 w-3.5 text-[var(--status-info)]"  aria-hidden="true"/>
    ) : todo.status === "completed" ? (
      <Icon name="checkbox-circle" className="h-3.5 w-3.5 text-[var(--status-success)]"  aria-hidden="true"/>
    ) : (
      <Icon name="time" className="h-3.5 w-3.5 text-muted-foreground"  aria-hidden="true"/>
    );

  return (
    <li
      ref={activeRef}
      aria-current={isActive ? "step" : undefined}
      className={cn(
        "group relative grid min-w-0 grid-cols-[1rem_minmax(0,1fr)] items-start gap-2.5 px-3 py-2.5",
        isActive && "bg-[var(--surface-muted)] before:absolute before:inset-y-2 before:left-0 before:w-0.5 before:rounded-full before:bg-[var(--status-info)]",
      )}
    >
      <Tooltip>
        <TooltipTrigger asChild>
          <span className="flex size-4 items-center justify-center">{statusIcon}</span>
        </TooltipTrigger>
        <TooltipContent side="left" sideOffset={6}>
          {t(statusKey as never)}
        </TooltipContent>
      </Tooltip>
      <span className="min-w-0 flex-1">
        <span className={cn("block text-xs leading-4", config.textClassName)}>{todo.content}</span>
      </span>
    </li>
  );
};

const EMPTY_TODOS: TodoItem[] = [];

interface StatusRowProps {
  // Working state
  isWorking?: boolean;
  statusText?: string | null;
  isGenericStatus?: boolean;
  isWaitingForPermission?: boolean;
  wasAborted?: boolean;
  abortActive?: boolean;
  retryInfo?: { attempt?: number; next?: number } | null;
  // Abort state (for mobile/vscode)
  showAbort?: boolean;
  onAbort?: () => void;
  // Abort status display
  showAbortStatus?: boolean;
  showAssistantStatus?: boolean;
  showTodos?: boolean;
  agentName?: string;
  leftAccessory?: React.ReactNode;
}

export const StatusRow: React.FC<StatusRowProps> = ({
  isWorking = false,
  statusText = null,
  isGenericStatus,
  isWaitingForPermission,
  wasAborted,
  abortActive,
  retryInfo,
  showAbort,
  onAbort,
  showAbortStatus,
  showAssistantStatus = true,
  showTodos = true,
  agentName,
  leftAccessory,
}) => {
  const { t } = useI18n();
  const [isExpanded, setIsExpanded] = React.useState(false);
  const currentSessionId = useSessionUIStore((state) => state.currentSessionId);
  const liveTodos = useDirectorySync(
    React.useCallback(
      (state) => {
        if (!showTodos || !currentSessionId) return EMPTY_TODOS;
        return state.todo[currentSessionId] ?? EMPTY_TODOS;
      },
      [currentSessionId, showTodos],
    ),
  );
  const persistedSessionTodos = useTodosPersistStore(
    React.useCallback(
      (state) => (showTodos && currentSessionId ? state.sessions[currentSessionId]?.todos : undefined),
      [currentSessionId, showTodos],
    ),
  );
  const todos: TodoItem[] = React.useMemo(() => {
    if (!currentSessionId) return EMPTY_TODOS;
    if (liveTodos.length > 0) return liveTodos;
    return persistedSessionTodos ?? EMPTY_TODOS;
  }, [liveTodos, persistedSessionTodos, currentSessionId]);
  const isMobile = useUIStore((state) => state.isMobile);
  const isCompact = isMobile || isVSCodeRuntime();

  // Filter out cancelled todos for display and keep original order.
  // This prevents items from jumping around when status changes.
  const visibleTodos = React.useMemo(() => {
    return todos.filter((todo) => todo.status !== "cancelled");
  }, [todos]);

  // Find the current active todo (first in_progress, or first pending)
  const activeTodo = React.useMemo(() => {
    return (
      visibleTodos.find((t) => t.status === "in_progress") ||
      visibleTodos.find((t) => t.status === "pending") ||
      null
    );
  }, [visibleTodos]);
  const focusedTodo = React.useMemo(
    () => visibleTodos.find((todo) => todo.status === "in_progress") ?? null,
    [visibleTodos],
  );

  // Calculate progress
  const progress = React.useMemo(() => {
    const total = todos.filter((t) => t.status !== "cancelled").length;
    const completed = todos.filter((t) => t.status === "completed").length;
    return { completed, total };
  }, [todos]);

  const statusSummary = React.useMemo(() => {
    const active = visibleTodos.filter((t) => t.status === "in_progress").length;
    const left = visibleTodos.filter((t) => t.status === "in_progress" || t.status === "pending").length;
    return { active, left };
  }, [visibleTodos]);

  const hasTodoContent = showTodos && statusSummary.left > 0;
  const hasAssistantContent = showAssistantStatus && (
    isWorking ||
    Boolean(wasAborted) ||
    Boolean(showAbortStatus)
  );
  const hasLeftAccessory = Boolean(leftAccessory);
  // Original logic from ChatInput
  const shouldRenderPlaceholder = !showAbortStatus && (wasAborted || !abortActive);

  const hasContent = hasAssistantContent || hasTodoContent || hasLeftAccessory;

  // Close popover when clicking outside
  const popoverRef = React.useRef<HTMLDivElement>(null);
  const todoListRef = React.useRef<HTMLUListElement>(null);
  const activeTodoRef = React.useRef<HTMLLIElement>(null);
  React.useLayoutEffect(() => {
    const list = todoListRef.current;
    const activeItem = activeTodoRef.current;
    if (!isExpanded || !list || !activeItem) return;

    const centeredScrollTop = activeItem.offsetTop - list.offsetTop - (list.clientHeight - activeItem.offsetHeight) / 2;
    const maxScrollTop = list.scrollHeight - list.clientHeight;
    list.scrollTop = Math.min(maxScrollTop, Math.max(0, centeredScrollTop));
  }, [isExpanded]);

  React.useEffect(() => {
    if (!isExpanded) return;

    const handleClickOutside = (event: MouseEvent) => {
      if (popoverRef.current && !popoverRef.current.contains(event.target as Node)) {
        setIsExpanded(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [isExpanded]);

  const toggleExpanded = () => setIsExpanded((prev) => !prev);
  const todoSummaryLabel = t('chat.statusRow.summary.activeLeft', {
    active: statusSummary.active,
    left: statusSummary.left,
  });

  // Abort button for mobile/vscode
  const abortButton = showAbort && onAbort ? (
    <button
      type="button"
      onClick={onAbort}
      className="flex items-center justify-center h-[1.2rem] w-[1.2rem] text-[var(--status-error)] transition-opacity hover:opacity-80 focus-visible:outline-none flex-shrink-0"
      aria-label={t('chat.statusRow.actions.stopGeneratingAria')}
    >
      <Icon name="close-circle" aria-hidden="true"/>
    </button>
  ) : null;

  // Todo trigger button
  const todoTrigger = hasTodoContent ? (
    <button
      type="button"
      onClick={toggleExpanded}
      className="flex items-center gap-1 flex-shrink-0 text-muted-foreground"
      aria-label={todoSummaryLabel}
      title={todoSummaryLabel}
    >
      {/* Desktop: show task text; Mobile/VSCode: just "Tasks" */}
      {!isCompact && activeTodo ? (
        <span className="status-row__active-todo typography-ui-label text-foreground truncate max-w-[200px]">
          {activeTodo.content}
        </span>
      ) : (
        <span className="typography-ui-label">{t('chat.statusRow.tasksTitle')}</span>
      )}
      <span className="typography-meta flex items-center gap-1 tabular-nums" aria-hidden="true">
        <span className="flex items-center gap-0.5">
          <Icon name="record-circle" className="h-3.5 w-3.5 text-[var(--status-info)]" />
          {statusSummary.active}
        </span>
        <span>·</span>
        <span className="flex items-center gap-0.5">
          <Icon name="time" className="h-3.5 w-3.5" />
          {statusSummary.left}
        </span>
      </span>
      {isExpanded ? (
        <Icon name="arrow-up-s" className="h-3.5 w-3.5" />
      ) : (
        <Icon name="arrow-down-s" className="h-3.5 w-3.5" />
      )}
    </button>
  ) : null;

  // Don't render if nothing to show
  if (!hasContent) {
    return null;
  }

  return (
    <div className={cn("mb-1", !hasLeftAccessory && "chat-column")} style={STATUS_ROW_CONTAINER_STYLE}>
      <div className={cn("flex items-center justify-between py-0.5 gap-2 h-[1.2rem]", hasLeftAccessory && "px-0.5")}>
        {/* Left: Abort status | Working placeholder | leftAccessory */}
        <div className={cn("flex-1 flex items-center min-w-0 gap-2", hasLeftAccessory ? "pl-1.5" : "overflow-x-hidden")}>
          {showAssistantStatus && showAbortStatus ? (
            <div className="flex h-full items-center text-[var(--status-error)] pl-0.5">
              <span className="flex items-center gap-1.5 typography-ui-label">
                <Icon name="close-circle" aria-hidden="true"/>
                {t('chat.statusRow.aborted')}
              </span>
            </div>
          ) : showAssistantStatus && shouldRenderPlaceholder ? (
            <WorkingPlaceholder
              key={currentSessionId ?? "no-session"}
              isWorking={isWorking}
              statusText={statusText}
              isGenericStatus={isGenericStatus}
              isWaitingForPermission={isWaitingForPermission}
              retryInfo={retryInfo}
              agentName={agentName}
            />
          ) : leftAccessory ? (
            leftAccessory
          ) : null}
        </div>

        {/* Right: Abort (mobile only) + Todo */}
        <div className={cn("relative flex items-center gap-2 flex-shrink-0", hasLeftAccessory ? "pr-1.5" : "-mr-3")} ref={popoverRef}>
          {abortButton}
          {todoTrigger}

          {/* Popover dropdown */}
          {isExpanded && hasTodoContent && (
            <div
              style={{
                maxWidth: "min(28rem, calc(100cqw - 4ch))",
                backgroundColor: "var(--surface-elevated)",
                color: "var(--surface-elevated-foreground)",
              }}
              className={cn(
                "absolute right-0 bottom-full mb-1 z-50",
                "w-[min(30rem,calc(100cqw-1rem))] min-w-[280px] overflow-hidden rounded-xl",
                "shadow-[inset_0_1px_0_0_rgba(255,255,255,0.8),inset_0_0_0_1px_rgba(0,0,0,0.04),0_0_0_1px_rgba(0,0,0,0.10),0_1px_2px_-0.5px_rgba(0,0,0,0.08),0_4px_8px_-2px_rgba(0,0,0,0.08),0_12px_20px_-4px_rgba(0,0,0,0.08)]",
                "dark:shadow-[inset_0_1px_0_0_rgba(255,255,255,0.12),inset_0_0_0_1px_rgba(255,255,255,0.08),0_0_0_1px_rgba(0,0,0,0.36),0_1px_1px_-0.5px_rgba(0,0,0,0.22),0_3px_3px_-1.5px_rgba(0,0,0,0.20),0_6px_6px_-3px_rgba(0,0,0,0.16)]",
                "animate-in fade-in-0 zoom-in-95 slide-in-from-bottom-2",
                "duration-150"
              )}
            >
              {/* Header */}
              <div className="flex items-center justify-between gap-3 border-b border-[var(--surface-subtle)] px-3 py-2.5">
                <span className="typography-ui-label font-medium text-foreground">{t('chat.statusRow.tasksTitle')}</span>
                <span className="typography-meta tabular-nums text-muted-foreground">
                  {progress.completed}/{progress.total}
                </span>
              </div>

              {/* Todo list */}
              <ul
                ref={todoListRef}
                className="m-0 max-h-[min(22rem,50vh)] list-none divide-y divide-[var(--surface-subtle)] overflow-y-auto p-0"
              >
                {visibleTodos.map((todo, index) => (
                  <TodoItemRow
                    key={todo.id ?? `todo-${index}`}
                    todo={todo}
                    isActive={todo === focusedTodo}
                    activeRef={todo === focusedTodo ? activeTodoRef : undefined}
                  />
                ))}
              </ul>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
