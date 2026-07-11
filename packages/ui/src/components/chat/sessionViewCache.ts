export type SessionViewSelection = {
    runtimeKey: string;
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

export type SessionViewRenderState = {
    renderedSelection: SessionViewSelection | null;
    cachedSessionViews: SessionViewCacheEntry[];
};

type SessionViewRenderIntent = Readonly<{
    key: string | null;
    selection: SessionViewSelection | null;
}>;

const normalizeEstimatedBytes = (estimatedBytes: number): number => {
    if (!Number.isFinite(estimatedBytes) || estimatedBytes < 0) {
        return 0;
    }
    return Math.ceil(estimatedBytes);
};

export const createSessionViewKey = ({ runtimeKey, sessionId, directory }: SessionViewSelection): string => {
    return JSON.stringify([runtimeKey, directory ?? '', sessionId]);
};

export const createSessionViewRenderIntent = (
    selection: SessionViewSelection | null,
): SessionViewRenderIntent => ({
    key: selection ? createSessionViewKey(selection) : null,
    selection,
});

const enforceSessionViewCacheLimits = (
    entries: SessionViewCacheEntry[],
    activeKey: string,
    limits: SessionViewCacheLimits,
): SessionViewCacheEntry[] => {
    const maxEntries = Math.max(1, Math.floor(limits.maxEntries));
    const maxEstimatedBytes = Math.max(0, limits.maxEstimatedBytes);
    let totalEstimatedBytes = entries.reduce((total, entry) => total + entry.estimatedBytes, 0);
    if (entries.length <= maxEntries && totalEstimatedBytes <= maxEstimatedBytes) {
        return entries;
    }

    const next = [...entries];

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

export const applyLatestSessionViewRenderIntent = (
    current: SessionViewRenderState,
    scheduledIntent: SessionViewRenderIntent,
    latestIntent: SessionViewRenderIntent,
    limits: SessionViewCacheLimits,
    estimatedBytes: number,
): SessionViewRenderState => {
    // Object identity is intentional: A -> B -> A creates a fresh second-A
    // intent even though its cache key matches the first A.
    if (scheduledIntent !== latestIntent) {
        return current;
    }

    const cachedSessionViews = scheduledIntent.selection
        ? reconcileSessionViewCache(
            current.cachedSessionViews,
            scheduledIntent.selection,
            limits,
            estimatedBytes,
        )
        : current.cachedSessionViews;

    if (
        current.renderedSelection === scheduledIntent.selection
        && cachedSessionViews === current.cachedSessionViews
    ) {
        return current;
    }

    return {
        renderedSelection: scheduledIntent.selection,
        cachedSessionViews,
    };
};
