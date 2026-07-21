import { describe, expect, mock, test } from "bun:test"
import React from "react"
import { renderToString } from "react-dom/server"

let renderCustomToast: ((id: string | number) => React.ReactElement) | undefined

mock.module("@/components/ui/toast", () => ({
  toast: {
    custom: (render: (id: string | number) => React.ReactElement) => {
      renderCustomToast = render
      return "toast-id"
    },
    dismiss: () => undefined,
    error: () => undefined,
  },
}))

mock.module("@/stores/useUIStore", () => ({
  useUIStore: {
    getState: () => ({ setArchivedSessionsDialogOpen: () => undefined }),
  },
}))

mock.module("@/sync/session-actions", () => ({
  SESSION_DELETE_UNDO_MS: 10_000,
  cancelScheduledSessionDeletes: () => undefined,
  scheduleSessionDeletes: () => ({ batchId: "", scheduledIds: [] }),
  unarchiveSession: async () => true,
}))

const { showArchivedSessionsUndoToast } = await import("./sessionMutationUndo")

describe("session mutation undo toast", () => {
  test("keeps custom content inside the padded toast on narrow screens", () => {
    showArchivedSessionsUndoToast({
      sessionIds: ["session-1"],
      message: "Session archived",
      undoLabel: "Undo",
      settingsLabel: "View archived",
      undoFailedMessage: "Undo failed",
    })

    expect(renderCustomToast).toBeDefined()
    const html = renderToString(renderCustomToast!("toast-id"))

    expect(html).toContain("w-full min-w-0 max-w-full")
    expect(html).toContain("flex-1 truncate")
  })
})
