import { describe, expect, test } from 'bun:test';
import { filterMethodsWithIndex, shouldLoadAvailableProviders } from './providerAvailability';

describe('ProvidersPage available provider loading', () => {
  test('loads available providers only in add-provider mode', () => {
    expect(shouldLoadAvailableProviders(false)).toBe(false);
    expect(shouldLoadAvailableProviders(true)).toBe(true);
  });

  test('keeps the original auth method index when selecting OAuth methods', () => {
    const methods = [
      { type: 'api', label: 'API key' },
      { type: 'oauth', label: 'ChatGPT browser' },
      { type: 'oauth', label: 'ChatGPT headless' },
    ];

    expect(filterMethodsWithIndex(methods, (method) => method.type === 'oauth')).toEqual([
      { method: methods[1], methodIndex: 1 },
      { method: methods[2], methodIndex: 2 },
    ]);
  });
});
