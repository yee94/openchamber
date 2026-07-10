import { describe, expect, test } from 'bun:test';

import { DualLimitLru } from './dualLimitLru';

describe('DualLimitLru', () => {
    test('evicts the least recently used entry by count', () => {
        const cache = new DualLimitLru<string, string>({ maxEntries: 2, maxBytes: 100 });
        cache.set('a', 'A', 10);
        cache.set('b', 'B', 10);
        expect(cache.get('a')).toBe('A');

        cache.set('c', 'C', 10);

        expect(cache.get('b')).toBe(undefined);
        expect(cache.get('a')).toBe('A');
        expect(cache.get('c')).toBe('C');
    });

    test('evicts by total byte weight even below the count limit', () => {
        const cache = new DualLimitLru<string, string>({ maxEntries: 10, maxBytes: 20 });
        cache.set('a', 'A', 12);
        cache.set('b', 'B', 12);

        expect(cache.get('a')).toBe(undefined);
        expect(cache.get('b')).toBe('B');
        expect(cache.byteSize).toBe(12);
    });

    test('does not retain an entry larger than the byte budget', () => {
        const cache = new DualLimitLru<string, string>({ maxEntries: 10, maxBytes: 20 });

        cache.set('oversized', 'value', 21);

        expect(cache.get('oversized')).toBe(undefined);
        expect(cache.size).toBe(0);
        expect(cache.byteSize).toBe(0);
    });
});
