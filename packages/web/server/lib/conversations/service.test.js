import { describe, expect, it, vi, beforeEach } from 'vitest';
import { validateConversationInput } from './validation.js';

// Mock the SDK module before any imports
vi.mock('@opencode-ai/sdk/v2', () => ({
  createOpencodeClient: vi.fn(),
}));

// Lazy import to allow vi.mock to take effect
const { createConversationsService } = await import('./service.js');

const mockCreateOpencodeClient = (await import('@opencode-ai/sdk/v2')).createOpencodeClient;

describe('conversations validation', () => {
  it('rejects non-object body', () => {
    const result = validateConversationInput(null);
    expect(result.valid).toBe(false);
    expect(result.errors).toContain('Request body must be a JSON object');
  });

  it('rejects missing input.type', () => {
    const result = validateConversationInput({ directory: '/test', parts: [] });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('input must be'))).toBe(true);
  });

  it('rejects non-prompt input type', () => {
    const result = validateConversationInput({ input: { type: 'command' }, directory: '/test', parts: [] });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('must be "prompt"'))).toBe(true);
  });

  it('rejects missing directory', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, messageID: 'msg_1', model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'text', text: 'hi' }],
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('directory'))).toBe(true);
  });

  it('rejects missing messageID', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'text', text: 'hi' }],
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('messageID'))).toBe(true);
  });

  it('rejects missing model', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      parts: [{ type: 'text', text: 'hi' }],
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('model'))).toBe(true);
  });

  it('rejects model without modelID', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      model: { providerID: 'p1' },
      parts: [{ type: 'text', text: 'hi' }],
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('modelID'))).toBe(true);
  });

  it('rejects empty text part', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'text', text: '   ' }],
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('non-empty'))).toBe(true);
  });

  it('rejects missing parts', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('parts'))).toBe(true);
  });

  it('rejects empty parts array', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' }, parts: [],
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('at least one part'))).toBe(true);
  });

  it('rejects delivery field', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'text', text: 'hi' }],
      delivery: 'steer',
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('"delivery"'))).toBe(true);
  });

  it('rejects format field', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'text', text: 'hi' }],
      format: { type: 'json_schema', schema: {} },
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('"format"'))).toBe(true);
  });

  it('rejects unknown top-level fields', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'text', text: 'hi' }],
      noReply: true,
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('"noReply"'))).toBe(true);
  });

  it('rejects invalid part type', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'invalid', text: 'hi' }],
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('Part type'))).toBe(true);
  });

  it('rejects subtask part type', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'subtask', prompt: 'test', description: 'test' }],
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('Part type'))).toBe(true);
  });

  it('rejects text part without text field', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'text' }],
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('"text" string field'))).toBe(true);
  });

  it('rejects file part without mime and url', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'file' }],
    });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('"mime"'))).toBe(true);
  });

  it('accepts valid minimal input (text only)', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' },
      directory: '/test/repo',
      messageID: 'msg_abc',
      model: { providerID: 'openai', modelID: 'gpt-4o' },
      parts: [{ type: 'text', text: 'hello world' }],
    });
    expect(result.valid).toBe(true);
    expect(result.sanitized.directory).toBe('/test/repo');
    expect(result.sanitized.delivery).toBeUndefined();
  });

  it('accepts full input with all optional fields', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' },
      directory: '/test/repo',
      messageID: 'msg_abc123',
      title: 'My Session',
      parentID: 'parent_xyz',
      agent: 'builder',
      variant: 'fast',
      model: { providerID: 'openai', modelID: 'gpt-4o' },
      metadata: { key: 'value' },
      parts: [
        { type: 'text', text: 'hello' },
        { type: 'file', mime: 'text/plain', url: 'file:///test.txt', filename: 'test.txt' },
        { type: 'agent', name: 'deployer' },
      ],
    });
    expect(result.valid).toBe(true);
    expect(result.sanitized.title).toBe('My Session');
    expect(result.sanitized.parentID).toBe('parent_xyz');
    expect(result.sanitized.agent).toBe('builder');
    expect(result.sanitized.variant).toBe('fast');
    expect(result.sanitized.metadata).toEqual({ key: 'value' });
    expect(result.sanitized.parts).toHaveLength(3);
  });

  it('accepts text part with synthetic and id fields', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' },
      directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'text', text: 'hi', synthetic: true, id: 'part_1' }],
    });
    expect(result.valid).toBe(true);
    expect(result.sanitized.parts[0].synthetic).toBe(true);
    expect(result.sanitized.parts[0].id).toBe('part_1');
  });

  it('accepts file part with source', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' },
      directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'file', mime: 'image/png', url: 'file:///img.png', source: { type: 'selection', path: '/img.png' } }],
    });
    expect(result.valid).toBe(true);
    expect(result.sanitized.parts[0].source).toEqual({ type: 'selection', path: '/img.png' });
  });

  it('accepts agent part with source', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' },
      directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'agent', name: 'builder', source: { value: '@builder', start: 0, end: 8 } }],
    });
    expect(result.valid).toBe(true);
    expect(result.sanitized.parts[0].name).toBe('builder');
  });

  it('rejects parts that are all whitespace text', () => {
    const result = validateConversationInput({
      input: { type: 'prompt' }, directory: '/test', messageID: 'msg_1',
      model: { providerID: 'o', modelID: 'g' },
      parts: [{ type: 'text', text: '  \n  ' }],
    });
    expect(result.valid).toBe(false);
  });
});

describe('conversations service', () => {
  const mockBuildUrl = vi.fn();
  const mockGetHeaders = vi.fn();
  const mockMarkSent = vi.fn();
  const mockWaitReady = vi.fn();

  const createService = () => createConversationsService({
    buildOpenCodeUrl: mockBuildUrl,
    getOpenCodeAuthHeaders: mockGetHeaders,
    markUserMessageSent: mockMarkSent,
    waitForOpenCodeReady: mockWaitReady,
  });

  beforeEach(() => {
    vi.clearAllMocks();
    mockBuildUrl.mockReturnValue('http://127.0.0.1:4096/');
    mockGetHeaders.mockReturnValue({ Authorization: 'Basic test' });
    mockWaitReady.mockResolvedValue(undefined);
    mockCreateOpencodeClient.mockReset();
  });

  const baseInput = (overrides = {}) => ({
    directory: '/test',
    messageID: 'msg_test',
    model: { providerID: 'openai', modelID: 'gpt-4o' },
    parts: [{ type: 'text', text: 'hello' }],
    ...overrides,
  });

  // --- readiness ---

  it('returns create failure when OpenCode is not ready', async () => {
    mockWaitReady.mockRejectedValue(new Error('health check timeout'));
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(false);
    expect(result.phase).toBe('create');
    expect(result.error).toBe('Failed to create session');
  });

  // --- create failures ---

  it('returns create failure with safe error when SDK returns error', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: null, error: new Error('internal: port 4096 unreachable'), response: { status: 500 } }),
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(false);
    expect(result.phase).toBe('create');
    expect(result.error).toBe('Failed to create session');
    expect(result.status).toBe(500);
    // Safe error — no path/port leaked
    expect(result.error).not.toContain('4096');
  });

  it('returns create failure on transport error during create', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => { throw new Error('Connection refused'); },
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(false);
    expect(result.phase).toBe('create');
    expect(result.error).toBe('Failed to create session');
  });

  // --- create: no agent/model ---

  it('does NOT pass agent/model/variant to session.create', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async (params) => {
          expect(params.agent).toBeUndefined();
          expect(params.model).toBeUndefined();
          return { data: { id: 'ses_ok' }, error: null, response: { status: 200 } };
        },
        promptAsync: async () => ({ data: undefined, error: null, response: { status: 204 } }),
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({
      sanitizedInput: baseInput({ agent: 'builder', variant: 'v1' }),
    });
    expect(result.ok).toBe(true);
  });

  // --- promptAsync usage ---

  it('uses promptAsync (not prompt) and does not pass delivery', async () => {
    let promptAsyncCalled = false;
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: { id: 'ses_pa' }, error: null, response: { status: 200 } }),
        promptAsync: async (params) => {
          promptAsyncCalled = true;
          expect(params.delivery).toBeUndefined();
          return { data: undefined, error: null, response: { status: 204 } };
        },
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(promptAsyncCalled).toBe(true);
    expect(result.ok).toBe(true);
  });

  // --- success ---

  it('returns success when create + promptAsync succeed', async () => {
    const sessionData = { id: 'ses_created', title: 'Test' };
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async (params) => {
          expect(params.directory).toBe('/test');
          return { data: sessionData, error: null, response: { status: 200 } };
        },
        promptAsync: async (params) => {
          expect(params.sessionID).toBe('ses_created');
          expect(params.messageID).toBe('msg_test');
          expect(params.model).toEqual({ providerID: 'openai', modelID: 'gpt-4o' });
          expect(params.parts).toEqual([{ type: 'text', text: 'hello' }]);
          return { data: undefined, error: null, response: { status: 204 } };
        },
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(true);
    expect(result.session).toEqual(sessionData);
    expect(result.messageID).toBe('msg_test');
    expect(mockMarkSent).toHaveBeenCalledWith('ses_created');
  });

  it('passes agent, variant to promptAsync', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: { id: 'ses_avd' }, error: null, response: { status: 200 } }),
        promptAsync: async (params) => {
          expect(params.agent).toBe('builder');
          expect(params.variant).toBe('fast');
          return { data: undefined, error: null, response: { status: 204 } };
        },
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({
      sanitizedInput: baseInput({ agent: 'builder', variant: 'fast' }),
    });
    expect(result.ok).toBe(true);
  });

  // --- permanent prompt errors (no mark) ---

  it('returns prompt failure with ambiguous=false for 400 SDK error, safe error, no mark', async () => {
    const sessionData = { id: 'ses_400' };
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: sessionData, error: null, response: { status: 200 } }),
        promptAsync: async () => ({
          data: null,
          error: new Error('path /foo/bar does not exist'),
          response: { status: 400 },
        }),
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(false);
    expect(result.phase).toBe('prompt');
    expect(result.ambiguous).toBe(false);
    expect(result.error).toBe('Failed to submit prompt');
    expect(result.status).toBe(400);
    expect(mockMarkSent).not.toHaveBeenCalled();
  });

  it('returns prompt failure with ambiguous=false for 404, no mark', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: { id: 'ses_404' }, error: null, response: { status: 200 } }),
        promptAsync: async () => ({
          data: null,
          error: new Error('Session not found'),
          response: { status: 404 },
        }),
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(false);
    expect(result.phase).toBe('prompt');
    expect(result.ambiguous).toBe(false);
    expect(result.error).toBe('Failed to submit prompt');
    expect(mockMarkSent).not.toHaveBeenCalled();
  });

  // --- ambiguous prompt errors (mark) ---

  it('returns ambiguous=true for 503, safe error, marks activity', async () => {
    const sessionData = { id: 'ses_503' };
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: sessionData, error: null, response: { status: 200 } }),
        promptAsync: async () => ({
          data: null,
          error: new Error('Service Unavailable'),
          response: { status: 503 },
        }),
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(false);
    expect(result.phase).toBe('prompt');
    expect(result.ambiguous).toBe(true);
    expect(result.error).toBe('Failed to submit prompt');
    expect(result.status).toBe(503);
    expect(mockMarkSent).toHaveBeenCalledWith('ses_503');
  });

  it('returns ambiguous=true for transport throw, marks activity', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: { id: 'ses_transport' }, error: null, response: { status: 200 } }),
        promptAsync: async () => { throw new TypeError('fetch failed'); },
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(false);
    expect(result.phase).toBe('prompt');
    expect(result.ambiguous).toBe(true);
    expect(result.error).toBe('Failed to submit prompt');
    expect(mockMarkSent).toHaveBeenCalledWith('ses_transport');
  });

  it('returns ambiguous=true for 408, marks activity', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: { id: 'ses_408' }, error: null, response: { status: 200 } }),
        promptAsync: async () => ({
          data: null,
          error: new Error('Request Timeout'),
          response: { status: 408 },
        }),
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.phase).toBe('prompt');
    expect(result.ambiguous).toBe(true);
    expect(mockMarkSent).toHaveBeenCalled();
  });

  it('returns ambiguous=true for 429, marks activity', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: { id: 'ses_429' }, error: null, response: { status: 200 } }),
        promptAsync: async () => ({
          data: null,
          error: new Error('Too Many Requests'),
          response: { status: 429 },
        }),
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.phase).toBe('prompt');
    expect(result.ambiguous).toBe(true);
    expect(mockMarkSent).toHaveBeenCalled();
  });

  it('does NOT mark on non-transport, non-ambiguous throw', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: { id: 'ses_perm' }, error: null, response: { status: 200 } }),
        promptAsync: async () => { throw new Error('Some permanent failure'); },
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ambiguous).toBe(false);
    expect(result.error).toBe('Failed to submit prompt');
    expect(mockMarkSent).not.toHaveBeenCalled();
  });

  // --- markUserMessageSent swallow ---

  it('safeMark does not throw when markUserMessageSent throws', async () => {
    const throwingMark = vi.fn(() => { throw new Error('mark boom'); });
    const svc = createConversationsService({
      buildOpenCodeUrl: mockBuildUrl,
      getOpenCodeAuthHeaders: mockGetHeaders,
      markUserMessageSent: throwingMark,
      waitForOpenCodeReady: mockWaitReady,
    });
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: { id: 'ses_safe' }, error: null, response: { status: 200 } }),
        promptAsync: async () => ({ data: undefined, error: null, response: { status: 204 } }),
      },
    });
    const result = await svc.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(true);
    expect(throwingMark).toHaveBeenCalled();
  });

  // --- directory/headers/readiness ---

  it('passes directory/headers through buildOpenCodeUrl and getOpenCodeAuthHeaders', async () => {
    mockBuildUrl.mockReturnValue('http://custom:9999/');
    mockGetHeaders.mockReturnValue({ Authorization: 'Bearer secret123' });
    mockCreateOpencodeClient.mockImplementation((config) => {
      expect(config.baseUrl).toBe('http://custom:9999');
      expect(config.headers).toEqual({ Authorization: 'Bearer secret123' });
      return {
        session: {
          create: async () => ({ data: { id: 'ses_url' }, error: null, response: { status: 200 } }),
          promptAsync: async () => ({ data: undefined, error: null, response: { status: 204 } }),
        },
      };
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(true);
  });

  it('awaits waitForOpenCodeReady before calling SDK', async () => {
    let createCalled = false;
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => { createCalled = true; return { data: { id: 'ses_w' }, error: null, response: { status: 200 } }; },
        promptAsync: async () => ({ data: undefined, error: null, response: { status: 204 } }),
      },
    });
    const service = createService();
    await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(mockWaitReady).toHaveBeenCalledWith(6000, 75);
    expect(createCalled).toBe(true);
  });

  // --- internal timeouts ---

  it('uses internal timeout signal for session.create', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async (_params, opts) => {
          expect(opts.signal).toBeDefined();
          expect(opts.signal.aborted).toBe(false);
          return { data: { id: 'ses_to' }, error: null, response: { status: 200 } };
        },
        promptAsync: async (_params, opts) => {
          expect(opts.signal).toBeDefined();
          return { data: undefined, error: null, response: { status: 204 } };
        },
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(true);
  });

  it('maps AbortError from create to create failure', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => { throw new DOMException('Aborted', 'AbortError'); },
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(false);
    expect(result.phase).toBe('create');
    expect(result.error).toBe('Failed to create session');
  });

  it('maps AbortError from promptAsync to ambiguous=true', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: { id: 'ses_pto' }, error: null, response: { status: 200 } }),
        promptAsync: async () => { throw new DOMException('Aborted', 'AbortError'); },
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(false);
    expect(result.phase).toBe('prompt');
    expect(result.ambiguous).toBe(true);
    expect(mockMarkSent).toHaveBeenCalledWith('ses_pto');
  });

  // --- create failure no session ID ---

  it('returns create failure when no session ID in response', async () => {
    mockCreateOpencodeClient.mockReturnValue({
      session: {
        create: async () => ({ data: null, error: null, response: { status: 200 } }),
      },
    });
    const service = createService();
    const result = await service.createAndPrompt({ sanitizedInput: baseInput() });
    expect(result.ok).toBe(false);
    expect(result.phase).toBe('create');
    expect(result.error).toBe('Failed to create session');
  });
});
