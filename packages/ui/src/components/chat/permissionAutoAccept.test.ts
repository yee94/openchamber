import { describe, expect, test } from 'bun:test';
import { shouldShowPermissionAutoAcceptControl } from './permissionAutoAccept';

describe('shouldShowPermissionAutoAcceptControl', () => {
    test('hides for a selected agent with a global allow rule', () => {
        expect(shouldShowPermissionAutoAcceptControl([
            { name: 'build', permission: [{ permission: '*', pattern: '*', action: 'allow' }] },
        ], 'build')).toBe(false);
    });

    test('normalizes string and object global allow rules', () => {
        expect(shouldShowPermissionAutoAcceptControl([{ name: 'build', permission: 'allow' }], 'build')).toBe(false);
        expect(shouldShowPermissionAutoAcceptControl([{ name: 'build', permission: { '*': 'allow' } }], 'build')).toBe(false);
    });

    test('shows when a later ask rule remains after global allow', () => {
        expect(shouldShowPermissionAutoAcceptControl([
            { name: 'build', permission: [
                { permission: '*', pattern: '*', action: 'allow' },
                { permission: 'bash', pattern: '*', action: 'ask' },
            ] },
        ], 'build')).toBe(true);
    });

    test('hides when a later global allow overrides an earlier ask rule', () => {
        expect(shouldShowPermissionAutoAcceptControl([
            { name: 'build', permission: [
                { permission: 'bash', pattern: '*', action: 'ask' },
                { permission: '*', pattern: '*', action: 'allow' },
            ] },
        ], 'build')).toBe(false);
    });

    test('shows for unknown snapshots, selected agents, and permission config', () => {
        expect(shouldShowPermissionAutoAcceptControl([], 'build')).toBe(true);
        expect(shouldShowPermissionAutoAcceptControl([{ name: 'build' }], 'build')).toBe(true);
        expect(shouldShowPermissionAutoAcceptControl([{ name: 'build', permission: 'unexpected' }], 'build')).toBe(true);
    });

    test('uses all available agents when the new-session agent is unresolved', () => {
        expect(shouldShowPermissionAutoAcceptControl([
            { name: 'build', permission: 'allow' },
            { name: 'plan', permission: { '*': 'allow' } },
        ], undefined)).toBe(false);
        expect(shouldShowPermissionAutoAcceptControl([
            { name: 'build', permission: 'allow' },
            { name: 'plan', permission: 'ask' },
        ], undefined)).toBe(true);
    });
});
