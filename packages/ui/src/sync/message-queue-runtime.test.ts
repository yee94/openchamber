import { expect, test } from "bun:test"
import { createMessageQueueRuntime } from "./message-queue-runtime"
import type { MessageQueueRuntimeController } from "./message-queue-runtime-controller"

test("runtime facade defers factory and durable migration until hydrate", async () => {
  let created = 0, migrated = 0
  const controller = { hydrate: async () => ({ status: "committed" as const, errors: [], cleanupErrors: [] }) } as unknown as MessageQueueRuntimeController
  const runtime = createMessageQueueRuntime(() => {
    created++
    return {
      controller,
      migrate: async () => {
        migrated++
        return { status: "committed" as const, snapshot: { version: 4 as const, queues: {}, migration: { v3State: "complete" as const } } }
      },
    }
  })
  expect(created).toBe(0); expect(migrated).toBe(0)
  await runtime.hydrate(); expect(created).toBe(1); expect(migrated).toBe(1)
})
test("runtime facade shares no-source hydration flight and permits recovery", async () => {
  let created = 0, migrated = 0, hydrated = 0, releaseMigration: (() => void) | undefined
  const migration = new Promise<void>((resolve) => { releaseMigration = resolve })
  const source = { version: 4 as const, queues: {}, migration: { v3State: "complete" as const } }
  const controller = { hydrate: async (source?: unknown) => { hydrated++; const status = source && typeof source === "object" && "status" in source ? "recovery-required" : "committed"; return { status, errors: [], cleanupErrors: [] } } } as unknown as MessageQueueRuntimeController
  const runtime = createMessageQueueRuntime(() => {
    created++
    return {
      controller,
      migrate: async () => {
        migrated++; await migration
        return migrated === 1 ? { status: "failed" as const } : { status: "committed" as const, snapshot: { version: 4 as const, queues: {}, migration: { v3State: "complete" as const } } }
      },
    }
  })
  const first = runtime.hydrate(), concurrent = runtime.hydrate(source)
  expect(first).toBe(concurrent); expect(created).toBe(1); expect(migrated).toBe(1); expect(hydrated).toBe(0)
  releaseMigration!(); expect((await first).status).toBe("recovery-required"); expect(hydrated).toBe(1)
  expect((await runtime.hydrate()).status).toBe("committed"); expect(migrated).toBe(2); expect(hydrated).toBe(2)
})
test("runtime facade shares explicit-source hydration flight", async () => {
  let migrated = 0, hydrated = 0, releaseHydrate: (() => void) | undefined
  const source = { version: 4 as const, queues: {}, migration: { v3State: "complete" as const } }
  const waiting = new Promise<void>((resolve) => { releaseHydrate = resolve })
  const controller = { hydrate: async () => { hydrated++; await waiting; return { status: "committed" as const, errors: [], cleanupErrors: [] } } } as unknown as MessageQueueRuntimeController
  const runtime = createMessageQueueRuntime(() => ({ controller, migrate: async () => { migrated++; return { status: "committed" as const, snapshot: source } } }))
  const first = runtime.hydrate(source), concurrent = runtime.hydrate(source)
  expect(first).toBe(concurrent); expect(migrated).toBe(0); expect(hydrated).toBe(1)
  releaseHydrate!(); await first; await runtime.hydrate(source)
  expect(hydrated).toBe(2); expect(migrated).toBe(0)
})
