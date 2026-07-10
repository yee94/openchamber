export type SessionViewSelection = {
    sessionId: string;
    directory: string | null;
};

export type SessionViewCacheEntry = SessionViewSelection & {
    key: string;
    estimatedBytes: number;
};

export type SessionViewCacheLimits = {
    maxEntries: number;
    maxEstimatedBytes: number;
};

const normalizeEstimatedBytes = (estimatedBytes: number): number => {
    if (!Number.isFinite(estimatedBytes) || estimatedBytes < 0) {
        return 0;
    }
    return Math.ceil(estimatedBytes);
};

export const createSessionViewKey = ({ sessionId, directory }: SessionViewSelection): string => {
    return JSON.stringify([directory ?? '', sessionId]);
};

const enforceSessionViewCacheLimits = (
    entries: SessionViewCacheEntry[],
    activeKey: string,
    limits: SessionViewCacheLimits,
): SessionViewCacheEntry[] => {
    const maxEntries = Math.max(1, Math.floor(limits.maxEntries));
    const maxEstimatedBytes = Math.max(0, limits.maxEstimatedBytes);
    const next = [...entries];
    let totalEstimatedBytes = next.reduce((total, entry) => total + entry.estimatedBytes, 0);

    while (next.length > maxEntries || totalEstimatedBytes > maxEstimatedBytes) {
        const evictionIndex = next.findIndex((entry) => entry.key !== activeKey);
        if (evictionIndex === -1) {
            break;
        }

        const [evicted] = next.splice(evictionIndex, 1);
        totalEstimatedBytes -= evicted?.estimatedBytes ?? 0;
    }

    return next;
};

export const reconcileSessionViewCache = (
    entries: SessionViewCacheEntry[],
    selection: SessionViewSelection,
    limits: SessionViewCacheLimits,
    estimatedBytes: number,
): SessionViewCacheEntry[] => {
    const key = createSessionViewKey(selection);
    const existingIndex = entries.findIndex((entry) => entry.key === key);
    const existing = existingIndex >= 0 ? entries[existingIndex] : undefined;
    const touchedEntry = existing
        ? existing
        : {
            ...selection,
            key,
            estimatedBytes: normalizeEstimatedBytes(estimatedBytes),
        };
    const next = existingIndex >= 0
        ? entries.filter((_, index) => index !== existingIndex)
        : [...entries];
    next.push(touchedEntry);

    return enforceSessionViewCacheLimits(next, key, limits);
};

export const updateSessionViewEstimate = (
    entries: SessionViewCacheEntry[],
    key: string,
    estimatedBytes: number,
    activeKey: string,
    limits: SessionViewCacheLimits,
): SessionViewCacheEntry[] => {
    const normalizedBytes = normalizeEstimatedBytes(estimatedBytes);
    const entryIndex = entries.findIndex((entry) => entry.key === key);
    if (entryIndex === -1) {
        return entries;
    }

    const current = entries[entryIndex];
    const next = current.estimatedBytes === normalizedBytes
        ? entries
        : entries.map((entry, index) => index === entryIndex
            ? { ...entry, estimatedBytes: normalizedBytes }
            : entry);

    return enforceSessionViewCacheLimits(next, activeKey, limits);
};
