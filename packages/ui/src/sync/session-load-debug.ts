const isEnabled = process.env.NODE_ENV === "development"

const startedAt = typeof performance !== "undefined" ? performance.now() : 0

export function sessionLoadDebug(event: string, details: Record<string, unknown> = {}): void {
  if (!isEnabled) return

  const elapsedMs = typeof performance !== "undefined"
    ? Math.round((performance.now() - startedAt) * 10) / 10
    : undefined

  console.info("[session-load]", JSON.stringify({ event, elapsedMs, ...details }))
}
