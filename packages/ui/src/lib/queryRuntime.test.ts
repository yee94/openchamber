import { QueryClient } from '@tanstack/react-query';
import { afterEach, beforeEach, describe, expect, test } from 'bun:test';
import { fetchQuotaProvider, installQueryRuntimeLifecycle, queryKeys } from './queryRuntime';
import { getRuntimeTransportIdentity, switchRuntimeEndpoint } from './runtime-switch';

describe('query runtime lifecycle', () => {
  const previousWindow = Object.getOwnPropertyDescriptor(globalThis, 'window');
  const listeners = new Set<(event: Event) => void>();

  beforeEach(() => {
    Object.defineProperty(globalThis, 'window', {
      configurable: true,
      value: {
        addEventListener: (_type: string, listener: (event: Event) => void) => listeners.add(listener),
        removeEventListener: (_type: string, listener: (event: Event) => void) => listeners.delete(listener),
        dispatchEvent: (event: Event) => {
          for (const listener of listeners) listener(event);
          return true;
        },
      },
    });
  });

  afterEach(() => {
    listeners.clear();
    switchRuntimeEndpoint({ apiBaseUrl: 'https://query-runtime-reset.example' });
    if (previousWindow) {
      Object.defineProperty(globalThis, 'window', previousWindow);
    } else {
      Reflect.deleteProperty(globalThis, 'window');
    }
  });

  test('keys queries by runtime transport identity', () => {
    switchRuntimeEndpoint({ apiBaseUrl: 'https://query-runtime-keys.example' });

    expect(queryKeys.runtime()).toEqual([getRuntimeTransportIdentity()]);
    expect(queryKeys.scoped('sessions', 'directory-a')).toEqual([
      getRuntimeTransportIdentity(),
      'sessions',
      'directory-a',
    ]);
    expect(queryKeys.quota('openai')).toEqual([
      getRuntimeTransportIdentity(),
      'openai',
    ]);
  });

  test('fetches a provider quota with the query abort signal', async () => {
    const previousFetch = globalThis.fetch;
    const controller = new AbortController();
    let receivedSignal: AbortSignal | undefined;
    globalThis.fetch = async (_input, init) => {
      receivedSignal = init?.signal ?? undefined;
      return new Response(JSON.stringify({ providerId: 'openai', providerName: 'OpenAI', ok: true, configured: true, usage: null, fetchedAt: 1 }));
    };

    try {
      await fetchQuotaProvider('openai', controller.signal);
      expect(receivedSignal).toBe(controller.signal);
    } finally {
      globalThis.fetch = previousFetch;
    }
  });

  test('clears cached queries when the runtime transport changes', () => {
    const client = new QueryClient();
    const dispose = installQueryRuntimeLifecycle(client);
    switchRuntimeEndpoint({ apiBaseUrl: 'https://query-runtime-a.example' });
    client.setQueryData(queryKeys.scoped('sessions'), ['session-a']);

    switchRuntimeEndpoint({ apiBaseUrl: 'https://query-runtime-b.example' });

    expect(client.getQueryCache().getAll()).toHaveLength(0);
    dispose();
  });

  test('preserves cached queries across credential refreshes and runtime key aliases', () => {
    const client = new QueryClient();
    const dispose = installQueryRuntimeLifecycle(client);
    switchRuntimeEndpoint({
      apiBaseUrl: 'https://query-runtime-stable.example',
      clientToken: 'first-token',
      runtimeKey: 'first-key',
    });
    const key = queryKeys.scoped('sessions');
    client.setQueryData(key, ['session-a']);

    switchRuntimeEndpoint({
      apiBaseUrl: 'https://query-runtime-stable.example/',
      clientToken: 'second-token',
      runtimeKey: 'second-key',
    });

    expect(client.getQueryData(key)).toEqual(['session-a']);
    dispose();
  });
});
