import { describe, expect, test } from "bun:test"
import { create, type StoreApi } from "zustand"
import type { SessionStatus } from "@opencode-ai/sdk/v2/client"

import { INITIAL_STATE, type State } from "../types"
import type { DirectoryStore } from "../child-store"
import {
  applySessionStatusSnapshot,
  collectSessionStatusSnapshotApplyIds,
  isLiveRevisionCurrent,
  resolveStrictDomainSessionID,
  shouldTriggerDomainRecovery,
  shouldTriggerStaleResync,
} from "../sync-context"

type StatusSnapshot = Record<string, { type: "idle" | "busy" | "retry"; attempt?: number; message?: string; next?: number }>

function createDirectoryStore(initial: Partial<State>): StoreApi<DirectoryStore> {
  return create<DirectoryStore>()((set) => ({
    ...INITIAL_STATE,
    ...initial,
    session: initial.session ?? [],
    patch: (partial) => set(partial),
    replace: (next) => set(next),
  }))
}

function streamingMessage() {
  // Trailing assistant message with no `time.completed` → actively streaming.
  return [{ id: "msg_1", role: "assistant", time: { created: 1 } }] as unknown as State["message"][string]
}

function completedMessage() {
  return [{ id: "msg_1", role: "assistant", time: { created: 1, completed: 2 } }] as unknown as State["message"][string]
}

const BUSY: SessionStatus = { type: "busy" }

describe("applySessionStatusSnapshot", () => {
  describe("one-shot snapshot (bootstrap / reconnect / escalated resync)", () => {
    test("keeps a newer busy state when an older absent snapshot completes", () => {
      const store = createDirectoryStore({
        session_status: { ses_a: BUSY },
        session_status_observed_at: { ses_a: 20 },
      })
      const changed = applySessionStatusSnapshot(store, {} as StatusSnapshot, ["ses_a"], 10)
      expect(changed).toBe(false)
      expect(store.getState().session_status.ses_a).toEqual(BUSY)
      expect(store.getState().session_status_observed_at.ses_a).toBe(20)
    })

    test("applies a newer snapshot and records its observation time", () => {
      const store = createDirectoryStore({
        session_status: { ses_a: BUSY },
        session_status_observed_at: { ses_a: 10 },
      })
      const changed = applySessionStatusSnapshot(store, {} as StatusSnapshot, ["ses_a"], 20)
      expect(changed).toBe(true)
      expect(store.getState().session_status.ses_a).toEqual({ type: "idle" })
      expect(store.getState().session_status_observed_at.ses_a).toBe(20)
    })

    test("lowers a busy session to idle when the snapshot omits it", () => {
      const store = createDirectoryStore({
        session_status: { ses_a: BUSY },
        message: { ses_a: completedMessage() },
      })
      const changed = applySessionStatusSnapshot(store, {} as StatusSnapshot, ["ses_a"])
      expect(changed).toBe(true)
      expect(store.getState().session_status.ses_a).toEqual({ type: "idle" })
    })

    test("snapshot is the source of truth: lowers to idle even if the trailing message looks unfinished", () => {
      // The live /session/status snapshot wins over derived message state — a
      // stale/lost message.updated must never pin a session busy after the
      // server says idle. (Recovery from a missed idle event.)
      const store = createDirectoryStore({
        session_status: { ses_a: BUSY },
        message: { ses_a: streamingMessage() },
      })
      const changed = applySessionStatusSnapshot(store, {} as StatusSnapshot, ["ses_a"])
      expect(changed).toBe(true)
      expect(store.getState().session_status.ses_a).toEqual({ type: "idle" })
    })

    test("records idle for a fresh client when the successful snapshot omits the candidate", () => {
      const store = createDirectoryStore({
        session_status: {},
        message: { ses_a: streamingMessage() },
      })
      const changed = applySessionStatusSnapshot(store, {} as StatusSnapshot, ["ses_a"])
      expect(changed).toBe(true)
      expect(store.getState().session_status.ses_a).toEqual({ type: "idle" })
    })

    test("raises an idle/unknown session to busy when the snapshot reports it active", () => {
      const store = createDirectoryStore({ session_status: {} })
      const changed = applySessionStatusSnapshot(store, { ses_a: { type: "busy" } }, ["ses_a"])
      expect(changed).toBe(true)
      expect(store.getState().session_status.ses_a).toEqual(BUSY)
    })

    test("updates busy → retry from the snapshot", () => {
      const store = createDirectoryStore({ session_status: { ses_a: BUSY } })
      const retry: SessionStatus = { type: "retry", attempt: 2, message: "x", next: 30 }
      applySessionStatusSnapshot(store, { ses_a: { type: "retry", attempt: 2, message: "x", next: 30 } }, ["ses_a"])
      expect(store.getState().session_status.ses_a).toEqual(retry)
    })

    test("reconnect apply set unions local candidates with snapshot IDs", () => {
      // A background session that went idle→busy while disconnected is present
      // only in the snapshot; local candidates alone would miss it.
      expect(collectSessionStatusSnapshotApplyIds(
        ["ses_local"],
        { ses_background: { type: "busy" } } as StatusSnapshot,
      ).sort()).toEqual(["ses_background", "ses_local"])
    })

    test("applies busy for a snapshot-only session after reconnect", () => {
      const store = createDirectoryStore({ session_status: { ses_local: { type: "idle" } } })
      const applyIds = collectSessionStatusSnapshotApplyIds(
        ["ses_local"],
        { ses_background: { type: "busy" } } as StatusSnapshot,
      )
      const changed = applySessionStatusSnapshot(
        store,
        { ses_background: { type: "busy" } } as StatusSnapshot,
        applyIds,
      )
      expect(changed).toBe(true)
      expect(store.getState().session_status.ses_background).toEqual(BUSY)
      expect(store.getState().session_status.ses_local).toEqual({ type: "idle" })
    })
  })
})

describe("shouldTriggerStaleResync", () => {
  const STALE_MS = 20_000
  const COOLDOWN_MS = 15_000

  test("does NOT trigger when heartbeats are recent (quiet-but-connected session)", () => {
    // 5s ago a heartbeat arrived — stream is alive even though no meaningful
    // events came through. This is the core fix for issue #1656.
    const now = 100_000
    const lastStreamActivityAt = now - 5_000
    expect(shouldTriggerStaleResync(lastStreamActivityAt, 0, now, STALE_MS, COOLDOWN_MS)).toBe(false)
  })

  test("does NOT trigger when a non-heartbeat event is recent", () => {
    const now = 100_000
    const lastStreamActivityAt = now - 3_000
    expect(shouldTriggerStaleResync(lastStreamActivityAt, 0, now, STALE_MS, COOLDOWN_MS)).toBe(false)
  })

  test("triggers when no events at all (including heartbeats) for the stale threshold", () => {
    const now = 100_000
    const lastStreamActivityAt = now - STALE_MS - 1
    expect(shouldTriggerStaleResync(lastStreamActivityAt, 0, now, STALE_MS, COOLDOWN_MS)).toBe(true)
  })

  test("does NOT trigger when within the resync cooldown even if stream is stale", () => {
    const now = 100_000
    const lastStreamActivityAt = now - STALE_MS - 1
    const lastFullResyncAt = now - 5_000 // only 5s ago, cooldown is 15s
    expect(shouldTriggerStaleResync(lastStreamActivityAt, lastFullResyncAt, now, STALE_MS, COOLDOWN_MS)).toBe(false)
  })

  test("triggers when stream is stale AND cooldown has elapsed", () => {
    const now = 100_000
    const lastStreamActivityAt = now - STALE_MS - 1
    const lastFullResyncAt = now - COOLDOWN_MS - 1
    expect(shouldTriggerStaleResync(lastStreamActivityAt, lastFullResyncAt, now, STALE_MS, COOLDOWN_MS)).toBe(true)
  })

  test("does NOT trigger when no events have been received yet (lastStreamActivityAt is 0)", () => {
    // Prevents firing before the first heartbeat arrives
    expect(shouldTriggerStaleResync(0, 0, 100_000, STALE_MS, COOLDOWN_MS)).toBe(false)
  })

  test("uses default thresholds when omitted", () => {
    const now = 100_000
    // 45s since last activity (> 40s default), 20s since last resync (> 15s default)
    expect(shouldTriggerStaleResync(now - 45_000, now - 20_000, now)).toBe(true)
    // 10s since last activity (< 40s default)
    expect(shouldTriggerStaleResync(now - 10_000, 0, now)).toBe(false)
  })
})

describe("shouldTriggerDomainRecovery", () => {
  const now = 100_000
  const base = {
    isViewed: true,
    status: BUSY,
    lastTransportActivityAt: now - 1_000,
    lastDomainActivityAt: now - 60_001,
    lastFullResyncAt: 0,
    now,
  }

  test("triggers for a viewed busy session with fresh transport and stale domain activity", () => {
    expect(shouldTriggerDomainRecovery(base)).toBe(true)
  })

  test("requires an active local status", () => {
    expect(shouldTriggerDomainRecovery({ ...base, status: { type: "idle" } })).toBe(false)
  })

  test("requires the currently viewed session", () => {
    expect(shouldTriggerDomainRecovery({ ...base, isViewed: false })).toBe(false)
  })

  test("leaves transport-stale recovery to the reconnect path", () => {
    expect(shouldTriggerDomainRecovery({ ...base, lastTransportActivityAt: now - 40_000 })).toBe(false)
  })

  test("respects the directory recovery cooldown", () => {
    expect(shouldTriggerDomainRecovery({ ...base, lastFullResyncAt: now - 30_000 })).toBe(false)
  })
})

describe("domain recovery event ownership and freshness", () => {
  test("does not assign an unknown message event to the viewed session", () => {
    const payload = {
      type: "message.part.delta",
      properties: { messageID: "msg_unknown", partID: "prt_1", field: "text", delta: "x" },
    } as never
    expect(resolveStrictDomainSessionID(payload, new Map([["msg_known", "ses_viewed"]]))).toBe(undefined)
  })

  test("resolves a known message event through the routing index", () => {
    const payload = {
      type: "message.part.delta",
      properties: { messageID: "msg_known", partID: "prt_1", field: "text", delta: "x" },
    } as never
    expect(resolveStrictDomainSessionID(payload, new Map([["msg_known", "ses_viewed"]]))).toBe("ses_viewed")
  })

  test("skips a recovery snapshot after its live revision changes", () => {
    expect(isLiveRevisionCurrent(4, 5)).toBe(false)
    expect(isLiveRevisionCurrent(4, 4)).toBe(true)
  })
})
