// --- stable fingerprint of sanitized input ---

const stableStringify = (value) => {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') return String(value);
  if (typeof value === 'string') return JSON.stringify(value);
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(',')}]`;
  }
  // object — skip null/undefined values
  const keys = Object.keys(value).sort();
  const pairs = [];
  for (const k of keys) {
    const v = value[k];
    if (v === null || v === undefined) continue;
    pairs.push(`${JSON.stringify(k)}:${stableStringify(v)}`);
  }
  return `{${pairs.join(',')}}`;
};

export const fingerprint = (sanitized) => stableStringify(sanitized);

// --- in-memory operation registry ---

const DEFAULT_MAX_ENTRIES = 500;
const DEFAULT_TTL_MS = 5 * 60 * 1000; // 5 min

export const createOperationRegistry = (deps = {}) => {
  const {
    maxEntries = DEFAULT_MAX_ENTRIES,
    ttlMs = DEFAULT_TTL_MS,
    clock = Date,
  } = deps;

  const entries = new Map(); // key → { status, result?, promise?, fingerprint, completedAt? }

  const isExpired = (entry) => {
    if (entry.status !== 'completed') return false;
    if (!Number.isFinite(entry.completedAt)) return false;
    return clock.now() - entry.completedAt >= ttlMs;
  };

  const evictExpired = () => {
    for (const [key, entry] of entries) {
      if (isExpired(entry)) {
        entries.delete(key);
      }
    }
  };

  const evictOldestCompleted = () => {
    let oldestKey = null;
    let oldestTime = Infinity;
    for (const [key, entry] of entries) {
      if (entry.status === 'completed' && Number.isFinite(entry.completedAt) && entry.completedAt < oldestTime) {
        oldestTime = entry.completedAt;
        oldestKey = key;
      }
    }
    if (oldestKey) entries.delete(oldestKey);
  };

  const countInflight = () => {
    let n = 0;
    for (const [, entry] of entries) if (entry.status === 'inflight') n += 1;
    return n;
  };

  const countCompleted = () => {
    let n = 0;
    for (const [, entry] of entries) if (entry.status === 'completed') n += 1;
    return n;
  };

  /**
   * Run an operation keyed by messageID with dedup and fingerprint safety.
   *
   * @param {string} key - messageID
   * @param {string} fp - stable fingerprint of sanitized input
   * @param {() => Promise<object>} factory
   * @returns {Promise<object>} { status, result, phase } where status is
   *   'dedup' (reused existing), 'conflict' (different payload), 'unavailable' (capacity), 'ran'
   */
  const run = async (key, fp, factory) => {
    // Lazy eviction on every run
    evictExpired();

    const existing = entries.get(key);

    // Same key, in-flight — reuse the promise
    if (existing && existing.status === 'inflight') {
      if (existing.fingerprint !== fp) {
        // Should not happen in practice with immediate validation, but guard it
        return { status: 'conflict', result: null, phase: 'conflict' };
      }
      try {
        const result = await existing.promise;
        return { status: 'dedup', result, phase: result.phase };
      } catch (_err) {
        // factory threw unexpectedly → treat as completed-internal, allow retry
        entries.delete(key);
        return { status: 'ran', result: { ok: false, phase: 'internal', error: 'Internal server error' }, phase: 'internal' };
      }
    }

    // Same key, completed — reuse result
    if (existing && existing.status === 'completed') {
      if (existing.fingerprint !== fp) {
        return { status: 'conflict', result: null, phase: 'conflict' };
      }
      return { status: 'dedup', result: existing.result, phase: existing.result.phase };
    }

    // Different key, same fingerprint → different messageID with same payload is ok (handled below)

    // Capacity check — only if this is a new key
    if (!existing) {
      // Evict expired first (already done above), then check total
      if (entries.size >= maxEntries) {
        const completedCount = countCompleted();
        if (completedCount > 0) {
          evictOldestCompleted();
        } else {
          // All entries are inflight — reject
          return { status: 'unavailable', result: null, phase: 'unavailable' };
        }
      }
    }

    // Register inflight entry
    let settle;
    const promise = new Promise((resolve, reject) => { settle = { resolve, reject }; });

    entries.set(key, {
      status: 'inflight',
      fingerprint: fp,
      promise,
      result: null,
      completedAt: null,
    });

    // Run factory
    try {
      const result = await factory();
      // Mark completed
      entries.set(key, {
        status: 'completed',
        fingerprint: fp,
        promise: null,
        result,
        completedAt: clock.now(),
      });
      settle.resolve(result);
      return { status: 'ran', result, phase: result.phase };
    } catch (_err) {
      // Unexpected factory throw — delete entry to allow retry.
      // Do NOT settle.reject() — there is no await'er for this promise
      // (it was created by us above) and rejecting would cause unhandled rejection.
      entries.delete(key);
      return { status: 'ran', result: { ok: false, phase: 'internal', error: 'Internal server error' }, phase: 'internal' };
    }
  };

  const snapshot = () => {
    const total = entries.size;
    const inflight = countInflight();
    const completed = countCompleted();
    return { total, inflight, completed };
  };

  return { run, snapshot };
};
