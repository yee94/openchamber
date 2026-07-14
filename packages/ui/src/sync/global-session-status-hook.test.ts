import { describe, expect, test } from "bun:test"
import type { SessionStatus } from "@opencode-ai/sdk/v2/client"

import { resolveGlobalSessionStatus } from "./sync-context"

describe("resolveGlobalSessionStatus", () => {
  test("uses the global busy status when no directory store is subscribed", () => {
    expect(resolveGlobalSessionStatus(undefined, "busy")).toEqual({ type: "busy" })
  })

  test("keeps the directory store's richer retry status", () => {
    const liveStatus = { type: "retry", attempt: 2, message: "rate limited", next: 10 } as SessionStatus

    expect(resolveGlobalSessionStatus(liveStatus, "busy")).toBe(liveStatus)
  })

  test("uses a newer global busy event over an older directory idle status", () => {
    const liveStatus = { type: "idle" } as SessionStatus

    expect(resolveGlobalSessionStatus(liveStatus, "busy", 100, 200)).toEqual({ type: "busy" })
  })
})
