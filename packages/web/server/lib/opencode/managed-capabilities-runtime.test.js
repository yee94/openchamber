import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import scheduledTaskPlugin from './managed-capabilities/scheduled-task.js';
import { SCHEDULED_TASK_BRIDGE_PATH, createManagedCapabilitiesRuntime, mergeManagedOpenCodeConfig } from './managed-capabilities-runtime.js';

describe('managed OpenCode capabilities runtime', () => {
  it('merges config while retaining unknown fields and stable plugin tuples', () => {
    const content = mergeManagedOpenCodeConfig({ configContent: JSON.stringify({ unknown: true, plugin: [['existing', { mode: 'safe' }]] }), pluginUrl: 'file:///scheduled-task.js', instructionsUrl: 'file:///instructions.md' });
    expect(JSON.parse(content)).toEqual({ unknown: true, plugin: [['existing', { mode: 'safe' }], 'file:///scheduled-task.js'], instructions: ['file:///instructions.md'] });
    expect(() => mergeManagedOpenCodeConfig({ configContent: '{', pluginUrl: 'file:///plugin.js', instructionsUrl: 'file:///instructions.md' })).toThrow('Invalid OPENCODE_CONFIG_CONTENT JSON');
  });

  it('publishes resources and authorizes only the active loopback child', async () => {
    const dataDir = await fs.mkdtemp(path.join(os.tmpdir(), 'openchamber-capabilities-'));
    let childPid = 44;
    const runtime = createManagedCapabilitiesRuntime({ dataDir, version: 'test', getManagedChildPid: () => childPid, isManagedChildAlive: (pid) => pid === 44 });
    try {
      runtime.setBridgeOrigin('http://127.0.0.1:3000');
      const childEnv = await runtime.prepareManagedChildEnv({ OPENCODE_CONFIG_CONTENT: '{"custom":true}' });
      runtime.recordManagedChildPid(44);
      const identity = runtime.getCapabilityIdentity();
      expect(childEnv.OPENCODE_CONFIG_CONTENT).toContain('scheduled-task.js');
      await expect(fs.access(path.join(dataDir, 'managed-opencode-capabilities', 'test', 'scheduled-task.js'))).resolves.toBeUndefined();
      const request = { method: 'POST', path: SCHEDULED_TASK_BRIDGE_PATH, socket: { remoteAddress: '127.0.0.1' }, headers: { 'x-openchamber-scheduled-task-token': identity.token } };
      expect(runtime.authorizeManagedOpenCodeBridgeRequest(request)).toBe(true);
      expect(runtime.authorizeManagedOpenCodeBridgeRequest({ ...request, method: 'GET' })).toBe(false);
      expect(runtime.authorizeManagedOpenCodeBridgeRequest({ ...request, socket: { remoteAddress: '10.0.0.2' } })).toBe(false);
      childPid = 45;
      expect(runtime.authorizeManagedOpenCodeBridgeRequest(request)).toBe(false);
    } finally {
      await fs.rm(dataDir, { recursive: true, force: true });
    }
  });
});

describe('scheduled_task plugin', () => {
  const originalEnv = { ...process.env };
  afterEach(() => { process.env = { ...originalEnv }; vi.restoreAllMocks(); });

  it('adds ask defaults, requests mutations, and forwards the context envelope', async () => {
    process.env.OPENCHAMBER_SCHEDULED_TASK_BRIDGE_ORIGIN = 'http://127.0.0.1:3000';
    process.env.OPENCHAMBER_SCHEDULED_TASK_BRIDGE_PATH = SCHEDULED_TASK_BRIDGE_PATH;
    process.env.OPENCHAMBER_SCHEDULED_TASK_BRIDGE_TOKEN = crypto.randomBytes(32).toString('hex');
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(JSON.stringify({ ok: true }), { status: 200 }));
    const plugin = await scheduledTaskPlugin();
    expect(await plugin.config({})).toEqual({ permission: { scheduled_task: 'ask' } });
    expect(await plugin.config({ permission: { '*': 'allow' } })).toEqual({ permission: { '*': 'allow' } });
    const ask = vi.fn(async () => {});
    await plugin.tool.scheduled_task.execute({ request: { operation: 'create', task: { title: 'later' } } }, { ask, sessionID: 'ses_1', messageID: 'msg_1', directory: '/repo', worktree: '/repo', agent: 'build' });
    expect(ask).toHaveBeenCalledWith(expect.objectContaining({ permission: 'scheduled_task', patterns: ['create'], always: ['create'] }));
    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toMatchObject({ context: { sessionID: 'ses_1', messageID: 'msg_1', agent: 'build' } });
  });
});
