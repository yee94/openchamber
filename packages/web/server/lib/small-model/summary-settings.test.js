import { afterAll, beforeEach, describe, expect, it, vi } from 'vitest';
import fsPromises from 'fs/promises';
import os from 'os';
import path from 'path';

const tempRoot = await fsPromises.mkdtemp(path.join(os.tmpdir(), 'oc-summary-settings-'));
const originalDataDir = process.env.OPENCHAMBER_DATA_DIR;
process.env.OPENCHAMBER_DATA_DIR = tempRoot;

vi.mock('../opencode/auth.js', () => ({
  readAuthFile: vi.fn(() => ({})),
}));

vi.mock('../opencode/shared.js', () => ({
  readConfigLayers: vi.fn(() => ({ mergedConfig: {} })),
}));

vi.mock('./catalog.js', () => ({
  getCatalogProvider: vi.fn(() => null),
  getModelCatalog: vi.fn(async () => ({})),
}));

vi.mock('./call.js', () => ({
  callSmallModel: vi.fn(async () => 'Generated summary'),
}));

const { generateSmallModelText } = await import('./index.js');
const { callSmallModel } = await import('./call.js');

describe('summary AI settings', () => {
  beforeEach(async () => {
    vi.mocked(callSmallModel).mockClear();
    await fsPromises.writeFile(path.join(tempRoot, 'settings.json'), JSON.stringify({
      summaryModelMode: 'custom',
      summaryCustomBaseURL: 'https://summary.example.test/v1',
      summaryModelID: 'summary-model',
      summaryCustomAPIToken: 'summary-token',
      summaryCommitPrompt: 'Return commit JSON.',
    }), 'utf8');
  });

  afterAll(async () => {
    if (originalDataDir === undefined) {
      delete process.env.OPENCHAMBER_DATA_DIR;
    } else {
      process.env.OPENCHAMBER_DATA_DIR = originalDataDir;
    }
    await fsPromises.rm(tempRoot, { recursive: true, force: true });
  });

  it('uses a persisted custom API and prompt for commit summaries', async () => {
    const result = await generateSmallModelText({
      purpose: 'commit',
      prompt: 'Diff content',
      system: 'Fallback system prompt',
      maxOutputTokens: 64,
    });

    expect(callSmallModel).toHaveBeenCalledWith(expect.objectContaining({
      providerID: 'custom',
      modelID: 'summary-model',
      system: 'Return commit JSON.',
      custom: {
        baseURL: 'https://summary.example.test/v1',
        apiToken: 'summary-token',
        modelID: 'summary-model',
      },
    }));
    expect(result).toEqual({
      text: 'Generated summary',
      providerID: 'custom',
      modelID: 'summary-model',
      source: 'summary-custom',
    });
    expect(JSON.stringify(result)).not.toContain('summary-token');
  });
});
