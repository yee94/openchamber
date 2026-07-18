import { describe, expect, test } from "bun:test"

import {
  createViewportIdentity,
  createViewportSnapshotSave,
  isSameViewportIdentity,
  shouldReplayViewportRestore,
} from "../hooks/useChatAutoFollow"
import { getViewportSessionMemory, useViewportStore } from "./viewport-store"

describe("viewport geometry keys", () => {
  test("keeps primary and panel geometry isolated for one session", () => {
    useViewportStore.setState({ sessionMemoryState: new Map() })
    const { updateViewportAnchor } = useViewportStore.getState()

    updateViewportAnchor("ses_1", 3, undefined, "primary:ses_1")
    updateViewportAnchor("ses_1", 7, undefined, "panel:ses_1")

    expect(getViewportSessionMemory("ses_1", "primary:ses_1")?.viewportAnchor).toBe(3)
    expect(getViewportSessionMemory("ses_1", "panel:ses_1")?.viewportAnchor).toBe(7)
  })

  test("keeps default session-keyed calls compatible", () => {
    useViewportStore.setState({ sessionMemoryState: new Map() })
    const { updateViewportAnchor } = useViewportStore.getState()

    updateViewportAnchor("ses_1", 4)

    expect(getViewportSessionMemory("ses_1")?.viewportAnchor).toBe(4)
  })

  test("captures one geometry key for snapshot save and restore", () => {
    useViewportStore.setState({ sessionMemoryState: new Map() })
    const identity = createViewportIdentity("ses_1", "panel:ses_1")
    const snapshot = createViewportSnapshotSave(
      identity,
      4,
      { scrollTop: 10, scrollHeight: 100, clientHeight: 50 },
    )

    useViewportStore.getState().updateViewportAnchor(
      snapshot.identity.sessionId as string,
      snapshot.anchor,
      snapshot.scrollPosition,
      snapshot.identity.viewportKey,
    )

    expect(getViewportSessionMemory(identity.sessionId as string, identity.viewportKey)?.scrollPosition).toEqual({
      scrollTop: 10,
      scrollHeight: 100,
      clientHeight: 50,
    })
  })

  test("treats a viewport key change as a distinct lifecycle identity", () => {
    const primary = createViewportIdentity("ses_1", "primary:ses_1")
    const panel = createViewportIdentity("ses_1", "panel:ses_1")

    expect(isSameViewportIdentity(primary, panel)).toBe(false)
    expect(isSameViewportIdentity(primary, createViewportIdentity("ses_1", "primary:ses_1"))).toBe(true)
    expect(shouldReplayViewportRestore(primary, panel)).toBe(false)
    expect(shouldReplayViewportRestore(primary, primary)).toBe(true)
  })
})
