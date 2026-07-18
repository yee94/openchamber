import React from "react";

import { Icon } from "@/components/icon/Icon";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useI18n } from "@/lib/i18n";
import { cn } from "@/lib/utils";

import { statusBarPopoverRowClassName } from "./statusBarPopover";

export type TodoItemStatus = "in_progress" | "pending" | "completed" | "cancelled";

export interface TodoItemRowTodo {
  id?: string;
  content: string;
  status: string;
}

interface TodoItemRowProps {
  todo: TodoItemRowTodo;
  isActive: boolean;
  activeRef?: React.Ref<HTMLLIElement>;
}

const statusTextClassName: Record<TodoItemStatus, string> = {
  in_progress: "text-foreground",
  pending: "text-foreground",
  completed: "text-muted-foreground line-through",
  cancelled: "text-muted-foreground line-through",
};

const statusLabelKey: Record<TodoItemStatus, string> = {
  in_progress: "chat.statusRow.todo.status.inProgress",
  pending: "chat.statusRow.todo.status.pending",
  completed: "chat.statusRow.todo.status.completed",
  cancelled: "chat.statusRow.todo.status.cancelled",
};

export const TodoItemRow: React.FC<TodoItemRowProps> = ({ todo, isActive, activeRef }) => {
  const { t } = useI18n();
  const status = TODO_ITEM_STATUSES.has(todo.status as TodoItemStatus) ? todo.status as TodoItemStatus : "pending";
  const statusLabel = t(statusLabelKey[status] as never);
  const statusIcon = status === "in_progress" ? (
    <Icon name="record-circle" className="h-3.5 w-3.5 text-[var(--status-info)]" aria-hidden="true" />
  ) : status === "completed" ? (
    <Icon name="checkbox-circle" className="h-3.5 w-3.5 text-[var(--status-success)]" aria-hidden="true" />
  ) : (
    <Icon name="time" className="h-3.5 w-3.5 text-muted-foreground" aria-hidden="true" />
  );

  return (
    <li
      ref={activeRef}
      aria-current={isActive ? "step" : undefined}
      className={cn(
        "group relative grid min-w-0 grid-cols-[1rem_minmax(0,1fr)] items-start gap-2.5",
        statusBarPopoverRowClassName,
        isActive && "bg-[var(--surface-muted)] before:absolute before:inset-y-2 before:left-0 before:w-0.5 before:rounded-full before:bg-[var(--status-info)]",
      )}
    >
      <Tooltip>
        <TooltipTrigger asChild>
          <span className="flex size-4 items-center justify-center" aria-label={statusLabel}>
            {statusIcon}
          </span>
        </TooltipTrigger>
        <TooltipContent side="left" sideOffset={6}>
          {statusLabel}
        </TooltipContent>
      </Tooltip>
      <span className="min-w-0 flex-1">
        <span className={cn("block whitespace-normal break-words", statusTextClassName[status])}>
          {todo.content}
        </span>
      </span>
    </li>
  );
};

const TODO_ITEM_STATUSES = new Set<TodoItemStatus>(["in_progress", "pending", "completed", "cancelled"]);
