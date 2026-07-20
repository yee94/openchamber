import { describe, expect, test, beforeEach } from 'bun:test';
import {
  clearResponseStyleSettingsCache,
  fetchResponseStyleInstruction,
  getCachedResponseStyleInstruction,
  rememberResponseStyleSettings,
} from './responseStyle';

describe('responseStyle send-path cache', () => {
  const previousFetch = globalThis.fetch;

  beforeEach(() => {
    clearResponseStyleSettingsCache();
    globalThis.fetch = previousFetch;
  });

  test('rememberResponseStyleSettings makes fetch sync from cache', async () => {
    let fetches = 0;
    globalThis.fetch = (async () => {
      fetches += 1;
      return new Response('{}', { status: 200 });
    }) as typeof fetch;

    rememberResponseStyleSettings({
      enabled: true,
      preset: 'concise',
      customInstructions: '',
    });

    const instruction = await fetchResponseStyleInstruction();
    expect(instruction).toContain('Keep replies short');
    expect(fetches).toBe(0);
    expect(getCachedResponseStyleInstruction()).toContain('Keep replies short');
  });

  test('disabled style caches as null without network', async () => {
    rememberResponseStyleSettings({ enabled: false, preset: 'detailed' });
    expect(await fetchResponseStyleInstruction()).toBeNull();
  });

  test('miss fetches once and warms the cache', async () => {
    let fetches = 0;
    globalThis.fetch = (async () => {
      fetches += 1;
      return new Response(JSON.stringify({
        responseStyleEnabled: true,
        responseStylePreset: 'noFiller',
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }) as typeof fetch;

    Object.defineProperty(globalThis, 'window', {
      configurable: true,
      value: { location: { origin: 'http://localhost:3000' } },
    });

    const first = await fetchResponseStyleInstruction();
    const second = await fetchResponseStyleInstruction();
    expect(first).toContain('Cut the filler');
    expect(second).toBe(first);
    expect(fetches).toBe(1);
  });
});
