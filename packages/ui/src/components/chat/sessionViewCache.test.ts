import { describe, expect, test } from 'bun:test';

import {
    createSessionViewKey,
    reconcileSessionViewCache,
    updateSessionViewEstimate,
    type SessionViewCacheEntry,
    type SessionViewCacheLimits,
} from './sessionViewCache';

const limits = (maxEntries: number, maxEstimatedBytes: number): SessionViewCacheLimits => ({
    maxEntries,
    maxEstimatedBytes,
});

const selection = (sessionId: string, directory: string, runtimeKey = 'runtime-a') => ({
    runtimeKey,
    sessionId,
    directory,
});

describe('sessionViewCache', () => {
    test('includes the directory in the cache key', () => {
        expect(createSessionViewKey(selection('session-1', '/repo/a')))
            .not.toBe(createSessionViewKey(selection('session-1', '/repo/b')));
    });

    test('includes the runtime identity in the cache key', () => {
        expect(createSessionViewKey(selection('session-1', '/repo', 'runtime-a')))
            .not.toBe(createSessionViewKey(selection('session-1', '/repo', 'runtime-b')));
    });

    test('reuses the same entry and promotes it on A → B → A', () => {
        const cacheLimits = limits(4, 64);
        const withA = reconcileSessionViewCache([], selection('a', '/repo'), cacheLimits, 8);
        const aEntry = withA[0];
        const withB = reconcileSessionViewCache(withA, selection('b', '/repo'), cacheLimits, 8);
        const revisitedA = reconcileSessionViewCache(withB, selection('a', '/repo'), cacheLimits, 8);

        expect(revisitedA.map((entry) => entry.sessionId)).toEqual(['b', 'a']);
        expect(revisitedA[1]).toBe(aEntry);
    });

    test('evicts the least recently used inactive view at the count limit', () => {
        const cacheLimits = limits(2, 64);
        let entries: SessionViewCacheEntry[] = [];
        entries = reconcileSessionViewCache(entries, selection('a', '/repo'), cacheLimits, 8);
        entries = reconcileSessionViewCache(entries, selection('b', '/repo'), cacheLimits, 8);
        entries = reconcileSessionViewCache(entries, selection('c', '/repo'), cacheLimits, 8);

        expect(entries.map((entry) => entry.sessionId)).toEqual(['b', 'c']);
    });

    test('evicts by estimated bytes even when the count limit is not reached', () => {
        const cacheLimits = limits(4, 16);
        let entries: SessionViewCacheEntry[] = [];
        entries = reconcileSessionViewCache(entries, selection('a', '/repo'), cacheLimits, 8);
        entries = reconcileSessionViewCache(entries, selection('b', '/repo'), cacheLimits, 8);
        entries = reconcileSessionViewCache(entries, selection('c', '/repo'), cacheLimits, 8);

        expect(entries.map((entry) => entry.sessionId)).toEqual(['b', 'c']);
    });

    test('a larger active estimate evicts old views but never evicts the active view', () => {
        const cacheLimits = limits(4, 16);
        let entries: SessionViewCacheEntry[] = [];
        entries = reconcileSessionViewCache(entries, selection('a', '/repo'), cacheLimits, 4);
        entries = reconcileSessionViewCache(entries, selection('b', '/repo'), cacheLimits, 4);
        const activeKey = createSessionViewKey(selection('b', '/repo'));

        entries = updateSessionViewEstimate(entries, activeKey, 20, activeKey, cacheLimits);

        expect(entries.map((entry) => entry.sessionId)).toEqual(['b']);
        expect(entries[0]?.estimatedBytes).toBe(20);
    });

    test('preserves the cache array when an estimate is unchanged', () => {
        const cacheLimits = limits(4, 64);
        const entries = reconcileSessionViewCache([], selection('a', '/repo'), cacheLimits, 8);
        const activeKey = createSessionViewKey(selection('a', '/repo'));

        const unchanged = updateSessionViewEstimate(entries, activeKey, 8, activeKey, cacheLimits);

        expect(unchanged).toBe(entries);
    });
});
