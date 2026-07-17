import { beforeEach, describe, expect, it, mock } from 'bun:test';
import { promisify } from 'node:util';

const execCalls = [];
const execMock = mock(() => {
  throw new Error('exec should be called through promisify');
});

execMock[promisify.custom] = (command, options) => {
  execCalls.push({ command, options });
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({ stdout: '/repo/.git\n/repo/.git\n', stderr: '' });
    }, 10);
  });
};

mock.module('child_process', () => ({
  exec: execMock,
}));

mock.module('vscode', () => ({
  workspace: {
    workspaceFolders: [{ uri: { fsPath: '/workspace' } }],
    fs: {},
  },
  Uri: {
    file: (fsPath) => ({ fsPath }),
  },
  FileType: {
    Directory: 2,
  },
  window: {},
}));

const readFileMock = mock();
mock.module('fs', () => ({
  promises: { readFile: readFileMock },
  default: { promises: { readFile: readFileMock } },
}));

const { clearGitReadCacheForTests, handleFsBridgeMessage } = await import('./bridge-fs-runtime');

const deps = {
  resolveUserPath: (value) => value,
  listDirectoryEntries: mock(),
  normalizeFsPath: (value) => value,
  execGit: mock(),
  searchDirectory: mock(),
  resolveFileReadPath: mock(),
  parseDroppedFileReference: mock(),
  readUriAsAttachment: mock(),
};

describe('bridge fs exec git read cache', () => {
  beforeEach(() => {
    execCalls.length = 0;
    clearGitReadCacheForTests();
  });

  it('dedupes in-flight cacheable git reads and reuses fresh results', async () => {
    const command = 'git rev-parse --absolute-git-dir --git-common-dir';
    const cwd = '/repo';

    const [first, second] = await Promise.all([
      handleFsBridgeMessage({ id: '1', type: 'api:fs:exec', payload: { commands: [command], cwd } }, deps),
      handleFsBridgeMessage({ id: '2', type: 'api:fs:exec', payload: { commands: [command], cwd } }, deps),
    ]);

    expect(first?.success).toBe(true);
    expect(second?.success).toBe(true);
    expect(execCalls).toHaveLength(1);

    const spacedCommand = 'git   rev-parse   --absolute-git-dir   --git-common-dir';
    const cached = await handleFsBridgeMessage({ id: '3', type: 'api:fs:exec', payload: { commands: [spacedCommand], cwd } }, deps);

    expect(execCalls).toHaveLength(1);
    expect(cached?.data?.results?.[0]).toMatchObject({
      command: spacedCommand,
      success: true,
      stdout: '/repo/.git\n/repo/.git',
    });
  });

  it('does not cache arbitrary exec commands', async () => {
    const command = 'git status --porcelain';
    const cwd = '/repo';

    await handleFsBridgeMessage({ id: '1', type: 'api:fs:exec', payload: { commands: [command], cwd } }, deps);
    await handleFsBridgeMessage({ id: '2', type: 'api:fs:exec', payload: { commands: [command], cwd } }, deps);

    expect(execCalls).toHaveLength(2);
  });
});

describe('bridge fs optional read', () => {
  beforeEach(() => {
    readFileMock.mockReset();
    deps.resolveFileReadPath.mockReset();
  });

  it('distinguishes a missing optional file from an empty existing file', async () => {
    deps.resolveFileReadPath.mockResolvedValue({ ok: true, resolvedPath: '/workspace/plan.md' });
    const missing = Object.assign(new Error('missing'), { code: 'ENOENT' });
    readFileMock.mockRejectedValueOnce(missing).mockResolvedValueOnce('');

    const missingResult = await handleFsBridgeMessage({
      id: 'missing',
      type: 'api:fs:read',
      payload: { path: '/workspace/plan.md', optional: true },
    }, deps);
    const emptyResult = await handleFsBridgeMessage({
      id: 'empty',
      type: 'api:fs:read',
      payload: { path: '/workspace/plan.md', optional: true },
    }, deps);

    expect(missingResult).toMatchObject({
      success: true,
      data: { content: '', path: '/workspace/plan.md', exists: false },
    });
    expect(emptyResult).toMatchObject({
      success: true,
      data: { content: '', path: '/workspace/plan.md', exists: true },
    });
  });
});
