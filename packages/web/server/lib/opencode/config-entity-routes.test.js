import { describe, expect, it, vi } from 'vitest';
import express from 'express';
import request from 'supertest';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

import { registerConfigEntityRoutes } from './config-entity-routes.js';

const createDependencies = (getCommandSources, configDirectory) => ({
  resolveProjectDirectory: async () => ({ directory: '/repo' }),
  resolveOptionalProjectDirectory: async () => ({ directory: '/repo' }),
  refreshOpenCodeAfterConfigChange: vi.fn(async () => ({})),
  clientReloadDelayMs: 0,
  getAgentSources: vi.fn(),
  getAgentConfig: vi.fn(),
  createAgent: vi.fn(),
  updateAgent: vi.fn(),
  deleteAgent: vi.fn(),
  getCommandSources,
  createCommand: vi.fn(),
  updateCommand: vi.fn(),
  deleteCommand: vi.fn(),
  listMcpConfigs: vi.fn(),
  getMcpConfig: vi.fn(),
  createMcpConfig: vi.fn(),
  updateMcpConfig: vi.fn(),
  deleteMcpConfig: vi.fn(),
  listSnippets: vi.fn(),
  getSnippet: vi.fn(),
  createSnippet: vi.fn(),
  updateSnippet: vi.fn(),
  deleteSnippet: vi.fn(),
  expandSnippets: vi.fn(),
  configDirectory,
});

describe('config entity command metadata route', () => {
  it('returns metadata for many commands through one request', async () => {
    const app = express();
    app.use(express.json());
    const getCommandSources = vi.fn((name) => ({
      md: { exists: name === 'project-command', scope: name === 'project-command' ? 'project' : null },
      json: { exists: name === 'user-command', scope: name === 'user-command' ? 'user' : null },
    }));
    registerConfigEntityRoutes(app, createDependencies(getCommandSources));

    const response = await request(app)
      .post('/api/config/commands/metadata?directory=%2Frepo')
      .send({ names: ['project-command', 'user-command', 'built-in', 'project-command'] })
      .expect(200);

    expect(getCommandSources).toHaveBeenCalledTimes(3);
    expect(response.body).toEqual({
      commands: {
        'project-command': { scope: 'project', isBuiltIn: false },
        'user-command': { scope: 'user', isBuiltIn: false },
        'built-in': { scope: null, isBuiltIn: true },
      },
    });
  });
});

describe('global raw configuration routes', () => {
  it('reads and validates the configured OpenCode and oh-my-opencode files', async () => {
    const app = express();
    app.use(express.json());
    const configDirectory = await fs.mkdtemp(path.join(os.tmpdir(), 'openchamber-global-config-'));
    await fs.writeFile(path.join(configDirectory, 'opencode.jsonc'), `{
  "$schema": "https://opencode.ai/config.json",
  "model": "imate/deepseek-v4-pro",
  "plugin": ["oh-my-opencode-slim"],
  // Existing comments must round-trip unchanged.
}`, 'utf8');
    await fs.writeFile(path.join(configDirectory, 'oh-my-opencode-slim.json'), JSON.stringify({
      scoringEngineVersion: 'v2',
      disabled_agents: ['observer'],
      agents: { fixer: { model: ['openai/gpt-5.6-terra'] } },
    }, null, 2), 'utf8');

    registerConfigEntityRoutes(app, createDependencies(vi.fn(), configDirectory));

    const openCode = await request(app).get('/api/config/global/opencode').expect(200);
    expect(openCode.body).toMatchObject({
      target: 'opencode',
      fileName: 'opencode.jsonc',
      content: expect.stringContaining('// Existing comments must round-trip unchanged.'),
    });

    const slim = await request(app).get('/api/config/global/oh-my-opencode-slim').expect(200);
    expect(slim.body.content).toContain('"disabled_agents"');

    const invalid = await request(app)
      .put('/api/config/global/opencode')
      .send({ content: '{ "model": }' })
      .expect(400);
    expect(invalid.body.error).toContain('Invalid JSONC');

    const saved = await request(app)
      .put('/api/config/global/opencode')
      .send({ content: '{\n  "model": "imate/deepseek-v4-pro",\n  // preserved JSONC syntax\n}' })
      .expect(200);
    expect(saved.body.content).toContain('// preserved JSONC syntax');
    expect(await fs.readFile(path.join(configDirectory, 'opencode.jsonc'), 'utf8')).toBe(saved.body.content);

    await fs.rm(configDirectory, { recursive: true, force: true });
  });

  it('discovers only existing configuration targets and prefers JSON files', async () => {
    const app = express();
    app.use(express.json());
    const configDirectory = await fs.mkdtemp(path.join(os.tmpdir(), 'openchamber-global-config-'));
    await fs.writeFile(path.join(configDirectory, 'opencode.json'), '{ "model": "json-model" }', 'utf8');
    await fs.writeFile(path.join(configDirectory, 'opencode.jsonc'), '{ "model": "jsonc-model" }', 'utf8');
    await fs.writeFile(path.join(configDirectory, 'oh-my-openagent.jsonc'), '{\n  // JSONC configuration\n}', 'utf8');

    registerConfigEntityRoutes(app, createDependencies(vi.fn(), configDirectory));

    const available = await request(app).get('/api/config/global').expect(200);
    expect(available.body).toEqual({
      targets: [
        { target: 'opencode', fileName: 'opencode.json' },
        { target: 'oh-my-openagent', fileName: 'oh-my-openagent.jsonc' },
      ],
    });

    const openCode = await request(app).get('/api/config/global/opencode').expect(200);
    expect(openCode.body).toMatchObject({ fileName: 'opencode.json', content: '{ "model": "json-model" }' });

    await request(app)
      .put('/api/config/global/opencode')
      .send({ content: '{ "model": "updated-json-model" }' })
      .expect(200);
    expect(await fs.readFile(path.join(configDirectory, 'opencode.json'), 'utf8')).toContain('updated-json-model');
    expect(await fs.readFile(path.join(configDirectory, 'opencode.jsonc'), 'utf8')).toContain('jsonc-model');

    await fs.rm(configDirectory, { recursive: true, force: true });
  });
});
