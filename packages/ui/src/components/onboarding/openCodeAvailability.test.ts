import { beforeEach, describe, expect, mock, test } from 'bun:test';

let response = new Response(null, { status: 500 });
const calls: Array<{ path: string; options?: { method?: string } }> = [];
const runtimeFetch = async (path: string, options?: { method?: string }) => {
  calls.push({ path, options });
  return response;
};

mock.module('@/lib/runtime-fetch', () => ({ runtimeFetch }));

const { checkOpenCodeAvailability, retryOpenCodeAvailability } = await import('./openCodeAvailability');

describe('OpenCode onboarding availability', () => {
  beforeEach(() => {
    calls.length = 0;
    response = new Response(null, { status: 500 });
  });

  test('reads readiness from the OpenChamber health snapshot', async () => {
    response = new Response(JSON.stringify({ isOpenCodeReady: true }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });

    expect(await checkOpenCodeAvailability()).toBe(true);
    expect(calls).toEqual([{ path: '/health', options: undefined }]);
  });

  test('keeps waiting when the health snapshot is not ready', async () => {
    response = new Response(JSON.stringify({ openCodeRunning: false, isOpenCodeReady: false }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });

    expect(await checkOpenCodeAvailability()).toBe(false);
  });

  test('requests a managed OpenCode startup retry', async () => {
    response = new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });

    expect(await retryOpenCodeAvailability()).toBe(true);
    expect(calls).toEqual([{ path: '/api/opencode/retry', options: { method: 'POST' } }]);
  });
});
