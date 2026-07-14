import { describe, expect, test } from "bun:test"

import {
  MAX_ASSISTANT_TAIL_PARENT_LOADS,
  findMissingAssistantParentUserIDs,
  loadSessionMessage,
  loadSessionMessagePage,
  recoverAssistantTailBoundary,
} from "../session-message-loader"

const record = (id: string, role: "user" | "assistant", parentID?: string) => ({ info: { id, role, parentID } })

describe("loadSessionMessagePage", () => {
  test("coalesces imperative and reactive requests for the same runtime session page", async () => {
    let calls = 0
    let release: ((value: string) => void) | undefined
    const request = () => {
      calls += 1
      return new Promise<string>((resolve) => {
        release = resolve
      })
    }

    const input = {
      runtimeKey: "runtime-a",
      directory: "/repo",
      sessionID: "ses_1",
      limit: 30,
      request,
    }
    const imperative = loadSessionMessagePage(input)
    const reactive = loadSessionMessagePage(input)

    expect(calls).toBe(1)
    release?.("page")
    expect(await imperative).toBe("page")
    expect(await reactive).toBe("page")
  })

  test("keeps cursor and runtime pages independent", async () => {
    let calls = 0
    const request = async () => ++calls

    await Promise.all([
      loadSessionMessagePage({ runtimeKey: "runtime-a", directory: "/repo", sessionID: "ses_1", limit: 30, request }),
      loadSessionMessagePage({ runtimeKey: "runtime-a", directory: "/repo", sessionID: "ses_1", limit: 30, before: "msg_20", request }),
      loadSessionMessagePage({ runtimeKey: "runtime-b", directory: "/repo", sessionID: "ses_1", limit: 30, request }),
    ])

    expect(calls).toBe(3)
  })

  test("clears a failed request so the next attempt can retry", async () => {
    let calls = 0
    const request = async () => {
      calls += 1
      if (calls === 1) throw new Error("not ready")
      return "recovered"
    }

    const input = { runtimeKey: "runtime-a", directory: "/repo", sessionID: "ses_1", limit: 30, request }
    await expect(loadSessionMessagePage(input)).rejects.toThrow("not ready")
    const recovered = await loadSessionMessagePage(input)
    expect(recovered).toBe("recovered")
    expect(calls).toBe(2)
  })

  test("keeps different limits independent for the same tail cursor", async () => {
    let calls = 0
    const request = async () => ++calls

    await Promise.all([
      loadSessionMessagePage({ runtimeKey: "runtime-a", directory: "/repo", sessionID: "ses_1", limit: 30, request }),
      loadSessionMessagePage({ runtimeKey: "runtime-a", directory: "/repo", sessionID: "ses_1", limit: 100, request }),
    ])

    expect(calls).toBe(2)
  })

  test("recovers missing user parents for an assistant-only tail", async () => {
    const recovered = await recoverAssistantTailBoundary({
      records: [record("assistant", "assistant", "user")],
      complete: false,
      requestMessage: async (messageID) => record(messageID, "user"),
    })

    expect(recovered.records.map((item) => item.info.id)).toEqual(["assistant", "user"])
    expect(recovered.boundaryFound).toBe(true)
    expect(recovered.partial).toBe(false)
  })

  test("keeps a user boundary and complete pages free of parent requests", async () => {
    let calls = 0
    const requestMessage = async (messageID: string) => {
      calls += 1
      return record(messageID, "user")
    }

    await recoverAssistantTailBoundary({ records: [record("user", "user"), record("assistant", "assistant", "missing")], complete: false, requestMessage })
    await recoverAssistantTailBoundary({ records: [record("assistant", "assistant", "missing")], complete: true, requestMessage })
    expect(calls).toBe(0)
  })

  test("deduplicates parent IDs and caps exact parent requests", () => {
    const records = Array.from({ length: MAX_ASSISTANT_TAIL_PARENT_LOADS + 3 }, (_, index) =>
      record(`assistant-${index}`, "assistant", `user-${index}`),
    )
    records.push(record("assistant-duplicate", "assistant", "user-0"))
    expect(findMissingAssistantParentUserIDs(records)).toEqual(Array.from({ length: MAX_ASSISTANT_TAIL_PARENT_LOADS }, (_, index) => `user-${index}`))
  })

  test("clears a failed parent request for retry", async () => {
    let calls = 0
    const input = {
      runtimeKey: "runtime-a",
      directory: "/repo",
      sessionID: "ses_1",
      messageID: "msg_1",
      request: async () => {
        calls += 1
        if (calls === 1) throw new Error("not ready")
        return "recovered"
      },
    }
    await expect(loadSessionMessage(input)).rejects.toThrow("not ready")
    expect(await loadSessionMessage(input)).toBe("recovered")
    expect(calls).toBe(2)
  })
})
