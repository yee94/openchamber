import { describe, expect, test } from "bun:test"
import type { Message } from "@opencode-ai/sdk/v2/client"

import { hasSessionMessageBoundary } from "../use-sync"

describe("hasSessionMessageBoundary", () => {
  test("requires a user boundary while a cached page remains partial", () => {
    const assistant = { id: "assistant", role: "assistant" } as Message
    const user = { id: "user", role: "user" } as Message

    expect(hasSessionMessageBoundary([assistant], false)).toBe(false)
    expect(hasSessionMessageBoundary([assistant, user], false)).toBe(true)
    expect(hasSessionMessageBoundary([assistant], true)).toBe(true)
  })
})
