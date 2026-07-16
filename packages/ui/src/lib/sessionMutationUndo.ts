import React from "react"
import { toast } from "@/components/ui/toast"
import { UndoCountdownRing } from "@/components/ui/UndoCountdownRing"
import { useUIStore } from "@/stores/useUIStore"
import {
  SESSION_DELETE_UNDO_MS,
  cancelScheduledSessionDeletes,
  scheduleSessionDeletes,
  unarchiveSession,
} from "@/sync/session-actions"

export { SESSION_DELETE_UNDO_MS }

type ArchiveUndoToastArgs = {
  sessionIds: string[]
  message: string
  undoLabel: string
  settingsLabel: string
  undoFailedMessage: string
}

type DeleteUndoToastArgs = {
  sessionIds: string[]
  message: string
  undoLabel: string
  commitFailedMessage: string
  delayMs?: number
}

function openArchivedSessionsManager(): void {
  useUIStore.getState().setArchivedSessionsDialogOpen(true)
}

function showSessionUndoToast(args: {
  durationMs: number
  message: string
  primaryLabel: string
  onPrimary: () => void
  secondaryLabel?: string
  onSecondary?: () => void
}): void {
  toast.custom(
    (id) => React.createElement(
      "div",
      {
        className:
          "flex items-center gap-2.5 rounded-[var(--radius-xl)] bg-[var(--surface-elevated)] px-3.5 py-2.5 text-foreground shadow-[0_0_0_1px_rgba(0,0,0,0.36),0_1px_1px_-0.5px_rgba(0,0,0,0.22),0_3px_3px_-1.5px_rgba(0,0,0,0.20)]",
      },
      React.createElement(UndoCountdownRing, { durationMs: args.durationMs }),
      React.createElement(
        "span",
        { className: "typography-ui-label font-medium whitespace-nowrap" },
        args.message,
      ),
      args.secondaryLabel && args.onSecondary
        ? React.createElement(
            "button",
            {
              type: "button",
              className:
                "rounded-[var(--radius-md)] bg-[var(--interactive-hover)] px-2 py-1 typography-meta font-medium text-foreground transition-colors hover:bg-[var(--interactive-active)]",
              onClick: () => {
                args.onSecondary?.()
                toast.dismiss(id)
              },
            },
            args.secondaryLabel,
          )
        : null,
      React.createElement(
        "button",
        {
          type: "button",
          className:
            "rounded-[var(--radius-md)] bg-[var(--primary-base)] px-2 py-1 typography-meta font-medium text-[var(--primary-foreground)] transition-opacity hover:opacity-85",
          onClick: () => {
            args.onPrimary()
            toast.dismiss(id)
          },
        },
        args.primaryLabel,
      ),
    ),
    {
      duration: args.durationMs,
      className: "session-mutation-undo-toast !p-0 !bg-transparent !border-0 !shadow-none",
    },
  )
}

/**
 * After a successful archive, show a short undo window and a shortcut into the
 * archived-sessions manager dialog. Do not expand the sidebar archived bucket.
 */
export function showArchivedSessionsUndoToast(args: ArchiveUndoToastArgs): void {
  const sessionIds = Array.from(new Set(args.sessionIds.filter(Boolean)))
  if (sessionIds.length === 0) return

  showSessionUndoToast({
    durationMs: SESSION_DELETE_UNDO_MS,
    message: args.message,
    primaryLabel: args.undoLabel,
    onPrimary: () => {
      void (async () => {
        const results = await Promise.all(sessionIds.map((id) => unarchiveSession(id)))
        if (results.some((ok) => !ok)) {
          toast.error(args.undoFailedMessage)
        }
      })()
    },
    secondaryLabel: args.settingsLabel,
    onSecondary: () => {
      openArchivedSessionsManager()
    },
  })
}

/**
 * Optimistically remove sessions and permanently delete after the undo window.
 * Undo cancels the server delete and restores local state.
 */
export function deleteSessionsWithUndo(args: DeleteUndoToastArgs): {
  batchId: string
  scheduledIds: string[]
} {
  const sessionIds = Array.from(new Set(args.sessionIds.filter(Boolean)))
  if (sessionIds.length === 0) {
    return { batchId: "", scheduledIds: [] }
  }

  const durationMs = args.delayMs ?? SESSION_DELETE_UNDO_MS
  const { batchId, scheduledIds } = scheduleSessionDeletes(sessionIds, {
    delayMs: durationMs,
    onSettled: ({ failedIds }) => {
      if (failedIds.length > 0) {
        toast.error(args.commitFailedMessage)
      }
    },
  })

  if (!batchId) {
    return { batchId, scheduledIds }
  }

  showSessionUndoToast({
    durationMs,
    message: args.message,
    primaryLabel: args.undoLabel,
    onPrimary: () => {
      cancelScheduledSessionDeletes(batchId)
    },
  })

  return { batchId, scheduledIds }
}
