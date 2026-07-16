import { describe, expect, it } from 'vitest';
import {
  isFullyAllowPermissionPolicy,
  normalizePermissionRules,
  shouldShowPermissionAutoAcceptControl,
} from './prompt-policy.js';

describe('normalizePermissionRules', () => {
  it('expands string allow', () => {
    expect(normalizePermissionRules('allow')).toEqual([
      { permission: '*', pattern: '*', action: 'allow' },
    ]);
  });

  it('expands object wildcard', () => {
    expect(normalizePermissionRules({ '*': 'allow' })).toEqual([
      { permission: '*', pattern: '*', action: 'allow' },
    ]);
  });

  it('keeps rulesets', () => {
    expect(normalizePermissionRules([
      { permission: 'bash', pattern: '*', action: 'ask' },
    ])).toEqual([
      { permission: 'bash', pattern: '*', action: 'ask' },
    ]);
  });
});

describe('isFullyAllowPermissionPolicy', () => {
  it('true for * allow', () => {
    expect(isFullyAllowPermissionPolicy({ '*': 'allow' })).toBe(true);
    expect(isFullyAllowPermissionPolicy('allow')).toBe(true);
  });

  it('false when any ask remains', () => {
    expect(isFullyAllowPermissionPolicy({
      '*': 'allow',
      bash: 'ask',
    })).toBe(false);
  });

  it('false when empty or partial allow', () => {
    expect(isFullyAllowPermissionPolicy(undefined)).toBe(false);
    expect(isFullyAllowPermissionPolicy({ bash: 'allow' })).toBe(false);
  });
});

describe('shouldShowPermissionAutoAcceptControl', () => {
  it('hides when config is fully allow and agents have no ask', () => {
    expect(shouldShowPermissionAutoAcceptControl({
      configPermission: { '*': 'allow' },
      agents: [
        { permission: [{ permission: '*', pattern: '*', action: 'allow' }] },
        { permission: [{ permission: 'edit', pattern: '*', action: 'allow' }] },
      ],
    })).toBe(false);
  });

  it('shows when config is fully allow but an agent asks', () => {
    expect(shouldShowPermissionAutoAcceptControl({
      configPermission: { '*': 'allow' },
      agents: [
        { permission: [{ permission: 'bash', pattern: '*', action: 'ask' }] },
      ],
    })).toBe(true);
  });

  it('hides when a later agent wildcard allow overrides earlier asks', () => {
    expect(shouldShowPermissionAutoAcceptControl({
      configPermission: { '*': 'allow' },
      agents: [
        { permission: [
          { permission: 'bash', pattern: '*', action: 'ask' },
          { permission: '*', pattern: '*', action: 'allow' },
        ] },
      ],
    })).toBe(false);
  });

  it('shows when config is not fully allow', () => {
    expect(shouldShowPermissionAutoAcceptControl({
      configPermission: { bash: 'ask' },
      agents: [],
    })).toBe(true);
  });

  it('shows when config unknown', () => {
    expect(shouldShowPermissionAutoAcceptControl({})).toBe(true);
  });
});
