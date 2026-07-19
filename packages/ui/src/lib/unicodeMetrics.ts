export const UNICODE_METRIC_CACHE_MAX_UTF16_LENGTH = 400_000

/** A bounded LRU cache for repeated Unicode scans on durable composer payloads. */
export const createUnicodeMetricCache = (measure: (text: string) => number = countUnicodeCodePointsUncached) => {
  const entries = new Map<string, number>()
  let totalLength = 0

  return {
    countUnicodeCodePoints: (text: string) => {
      const cached = entries.get(text)
      if (cached !== undefined) {
        entries.delete(text)
        entries.set(text, cached)
        return cached
      }
      const count = measure(text)
      if (text.length > UNICODE_METRIC_CACHE_MAX_UTF16_LENGTH) return count
      while (totalLength + text.length > UNICODE_METRIC_CACHE_MAX_UTF16_LENGTH && entries.size > 0) {
        const oldest = entries.keys().next().value as string
        totalLength -= oldest.length
        entries.delete(oldest)
      }
      entries.set(text, count)
      totalLength += text.length
      return count
    },
  }
}

const countUnicodeCodePointsUncached = (text: string): number => {
  let count = 0
  for (let index = 0; index < text.length; index += 1) {
    const unit = text.charCodeAt(index)
    if (unit >= 0xd800 && unit <= 0xdbff && index + 1 < text.length) {
      const next = text.charCodeAt(index + 1)
      if (next >= 0xdc00 && next <= 0xdfff) index += 1
    }
    count += 1
  }
  return count
}

const unicodeMetricCache = createUnicodeMetricCache()

export const countUnicodeCodePoints = (text: string): number => unicodeMetricCache.countUnicodeCodePoints(text)
