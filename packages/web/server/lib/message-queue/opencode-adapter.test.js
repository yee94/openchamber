import { describe, expect, it, vi } from 'vitest';

vi.mock('@opencode-ai/sdk/v2', () => ({ createOpencodeClient: vi.fn() }));
const { createOpencodeClient } = await import('@opencode-ai/sdk/v2');
const { createOpenCodeMessageQueueAdapter } = await import('./opencode-adapter.js');

describe('OpenCode message queue adapter', () => {
  it('captures runtime, materializes text and files, and sends the captured configuration', async () => {
    const promptAsync = vi.fn(() => ({ data: {} })); createOpencodeClient.mockReturnValue({ session: { promptAsync, messages: vi.fn(() => ({ data: [] })) } });
    let generation = 1;
    const adapter = createOpenCodeMessageQueueAdapter({ waitForReady: vi.fn(), buildOpenCodeUrl: () => 'http://open.code/', getOpenCodeAuthHeaders: () => ({ Authorization: 'secret' }), getRuntimeConfig: () => ({ apiBaseUrl: 'http://open.code' }), getRuntimeGeneration: () => generation, getSessionEligibility: () => ({ idle: true, settled: true }), getLatestMessageID: () => 'old', readAttachment: () => ({ type: 'file', url: 'file:///attachment' }) });
    const runtime = adapter.captureRuntime(); const scope = { sessionID: 'session', directory: '/repo' }; expect(await adapter.checkEligibility(scope)).toMatchObject({ idle: true, settled: true });
    const parts = await adapter.materializeAttachments({ content: 'text', attachments: [{}] }); expect(parts).toEqual([{ type: 'text', text: 'text' }, { type: 'file', url: 'file:///attachment' }]);
    await adapter.send({ scope, messageID: 'message', runtime, sendConfig: { providerID: 'p', modelID: 'm', agent: 'a', variant: 'v' }, parts }); expect(promptAsync).toHaveBeenCalledWith(expect.objectContaining({ sessionID: 'session', directory: '/repo', messageID: 'message', parts }), expect.any(Object));
    generation = 2; expect(await adapter.send({ scope, runtime, sendConfig: { providerID: 'p', modelID: 'm' } })).toMatchObject({ code: 'runtime_stale' });
  });
  it('classifies SDK results and exact reconciliation matches without exposing transport details', async () => {
    const messages = vi.fn(() => ({ data: [{ id: 'other' }, { id: 'wanted' }] })); createOpencodeClient.mockReturnValue({ session: { promptAsync: vi.fn(() => ({ error: {}, response: { status: 503 } })), messages } });
    const adapter = createOpenCodeMessageQueueAdapter({ buildOpenCodeUrl: () => 'http://open.code/', getOpenCodeAuthHeaders: () => ({}), getSessionEligibility: () => ({ idle: true, settled: true }), getLatestMessageID: () => null, readAttachment: () => null });
    expect(await adapter.send({ scope: { sessionID: 's', directory: '/d' }, messageID: 'm', sendConfig: { providerID: 'p', modelID: 'm' } })).toMatchObject({ kind: 'ambiguous', status: 503 }); expect(await adapter.findMessage({ sessionID: 's', directory: '/d' }, 'wanted')).toEqual({ found: true });
  });
  it('uses absent session status as idle and derives settlement from the message tail', async () => {
    const messages = vi.fn(() => ({ data: [] })); createOpencodeClient.mockReturnValue({ session: { messages, status: vi.fn(() => ({ data: {} })) } });
    const adapter = createOpenCodeMessageQueueAdapter({ buildOpenCodeUrl: () => 'http://open.code/', getOpenCodeAuthHeaders: () => ({}), readAttachment: () => null });
    expect(await adapter.checkEligibility({ sessionID: 's', directory: '/d' })).toMatchObject({ idle: true, settled: true });
    messages.mockReturnValueOnce({ data: [{ info: { role: 'user' } }] }); expect((await adapter.checkEligibility({ sessionID: 's', directory: '/d' })).settled).toBe(false);
    messages.mockReturnValueOnce({ data: [{ info: { role: 'assistant', time: { completed: 1 } } }] }); expect((await adapter.checkEligibility({ sessionID: 's', directory: '/d' })).settled).toBe(true);
  });
});
