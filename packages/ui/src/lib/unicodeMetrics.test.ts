import { describe, expect, test } from "bun:test"
import { createUnicodeMetricCache, UNICODE_METRIC_CACHE_MAX_UTF16_LENGTH } from "./unicodeMetrics"

describe("unicode metrics", () => {
  test("shares scans for identical strings and counts UTF-16 surrogate pairs", () => {
    let scans = 0
    const cache = createUnicodeMetricCache((text) => { scans += 1; return [...text].length })
    expect(cache.countUnicodeCodePoints("a😀")).toBe(2)
    expect(cache.countUnicodeCodePoints("a😀")).toBe(2)
    expect(cache.countUnicodeCodePoints("a😃")).toBe(2)
    expect(scans).toBe(2)
  })

  test("evicts least-recently-used payloads within the UTF-16 budget", () => {
    let scans = 0
    const cache = createUnicodeMetricCache((text) => { scans += 1; return text.length })
    const first = "a".repeat(200_000)
    const second = "b".repeat(200_000)
    const third = "c"
    cache.countUnicodeCodePoints(first)
    cache.countUnicodeCodePoints(second)
    cache.countUnicodeCodePoints(first)
    cache.countUnicodeCodePoints(third)
    cache.countUnicodeCodePoints(second)
    expect(UNICODE_METRIC_CACHE_MAX_UTF16_LENGTH).toBe(400_000)
    expect(scans).toBe(4)
  })
})
