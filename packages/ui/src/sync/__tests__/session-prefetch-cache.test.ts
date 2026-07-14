import { describe, expect, test } from "bun:test"

import {
  beginSessionMessageLoad,
  failSessionMessageLoad,
  getSessionPrefetch,
  setSessionPrefetch,
  shouldSkipSessionPrefetch,
} from "../session-prefetch-cache"

describe("shouldSkipSessionPrefetch", () => {
  test("does not skip when only metadata exists without cached messages", () => {
    expect(shouldSkipSessionPrefetch({
      hasMessages: false,
      info: { limit: 200, complete: true, at: 1_000, status: "ready" },
      pageSize: 200,
      now: 1_001,
    })).toBe(false)
  })

  test("does not skip a larger fetch when only a smaller partial prefetch is cached", () => {
    expect(shouldSkipSessionPrefetch({
      hasMessages: true,
      info: { limit: 50, complete: false, at: 1_000, status: "ready" },
      pageSize: 200,
      now: 1_001,
    })).toBe(false)
  })

  test("still skips a recent partial prefetch when cached coverage matches the request", () => {
    expect(shouldSkipSessionPrefetch({
      hasMessages: true,
      info: { limit: 200, complete: false, at: 1_000, status: "ready" },
      pageSize: 200,
      now: 1_001,
    })).toBe(true)
  })

  test("keeps pagination metadata through loading and error states", () => {
    const directory = "/prefetch-state"
    const sessionID = "session-state"
    setSessionPrefetch({ directory, sessionID, limit: 30, cursor: "cursor", complete: false, at: 1_000 })

    beginSessionMessageLoad(directory, sessionID)
    expect(getSessionPrefetch(directory, sessionID)).toEqual({ limit: 30, cursor: "cursor", complete: false, at: 1_000, status: "loading" })

    failSessionMessageLoad(directory, sessionID, "network unavailable")
    expect(getSessionPrefetch(directory, sessionID)).toEqual({ limit: 30, cursor: "cursor", complete: false, at: 1_000, status: "error", error: "network unavailable" })
  })

  test("isolates loading state by runtime", () => {
    const directory = "/runtime-scoped-prefetch"
    const sessionID = "shared-session"

    beginSessionMessageLoad(directory, sessionID, "runtime-a")
    setSessionPrefetch({ directory, sessionID, runtimeKey: "runtime-b", limit: 30, complete: false, at: 2_000 })

    expect(getSessionPrefetch(directory, sessionID, "runtime-a")?.status).toBe("loading")
    expect(getSessionPrefetch(directory, sessionID, "runtime-b")?.status).toBe("ready")
  })
})
