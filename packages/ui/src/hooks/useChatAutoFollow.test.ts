import { describe, expect, test } from 'vitest';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
    isWithinSessionOpenPinGrace,
    resolveAutoFollowPinnedFromDistance,
    resolveChatScrollPhysics,
    SESSION_OPEN_PIN_GRACE_MS,
    shouldWriteAutoFollowScrollTop,
} from './useChatAutoFollow';

const here = dirname(fileURLToPath(import.meta.url));

describe('session-open pin grace', () => {
    test('ignores leftover gestures until the grace expires', () => {
        expect(isWithinSessionOpenPinGrace(100, 550)).toBe(true);
        expect(isWithinSessionOpenPinGrace(550, 550)).toBe(false);
        expect(isWithinSessionOpenPinGrace(551, 550)).toBe(false);
    });

    test('restoreSnapshot arms the grace and force-pins on mobile', () => {
        const source = readFileSync(join(here, 'useChatAutoFollow.ts'), 'utf8');
        expect(source).toContain('armSessionOpenPinGrace()');
        expect(source).toContain('forceBottomDefeatingMomentum()');
        expect(source).toContain('isWithinSessionOpenPinGrace(now(), sessionOpenPinGraceUntilRef.current)');
        expect(SESSION_OPEN_PIN_GRACE_MS).toBeGreaterThan(0);
    });
});

describe('tanstack scroll physics', () => {
    test('does not assign scrollTop when tanstack owns the scroller', () => {
        expect(shouldWriteAutoFollowScrollTop('tanstack')).toBe(false);
        expect(shouldWriteAutoFollowScrollTop('dom')).toBe(true);
        expect(resolveChatScrollPhysics(() => 'tanstack')).toBe('tanstack');
        expect(resolveChatScrollPhysics(undefined)).toBe('dom');
        expect(resolveAutoFollowPinnedFromDistance(80)).toBe(true);
        expect(resolveAutoFollowPinnedFromDistance(81)).toBe(false);
        expect(resolveAutoFollowPinnedFromDistance(null)).toBe(false);

        const source = readFileSync(join(here, 'useChatAutoFollow.ts'), 'utf8');
        expect(source).toContain('if (!ownsScrollTop())');
        expect(source).toContain("resolvePhysics() === 'tanstack'");
        expect(source).toContain('jumpToLatestOwned()');
        expect(source).not.toContain('use-stick-to-bottom');
    });

    test('tanstack content resize and chunk handlers skip scrollTop writes', () => {
        const source = readFileSync(join(here, 'useChatAutoFollow.ts'), 'utf8');
        const resizeStart = source.indexOf('const handleContentResize = useEvent(');
        const resizeEnd = source.indexOf('const canObserveResize', resizeStart);
        const resize = source.slice(resizeStart, resizeEnd);
        expect(resize).toContain('if (!ownsScrollTop())');
        expect(resize).not.toMatch(/if \(!ownsScrollTop\(\)\)[\s\S]*el\.scrollTop\s*=/);

        const kickStart = source.indexOf('const kick = () =>');
        const kickEnd = source.indexOf('const handlers: AnimationHandlers', kickStart);
        expect(source.slice(kickStart, kickEnd)).toContain('ownsScrollTop()');
    });
});
