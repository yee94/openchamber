import { beforeEach, describe, expect, it, vi } from 'vitest';

const gitLibraries = {
  stageFiles: vi.fn(),
  unstageFiles: vi.fn(),
  createWorktree: vi.fn(),
  removeWorktree: vi.fn(),
  getWorktrees: vi.fn(),
};

vi.mock('./index.js', () => ({
  stageFiles: gitLibraries.stageFiles,
  unstageFiles: gitLibraries.unstageFiles,
  createWorktree: gitLibraries.createWorktree,
  removeWorktree: gitLibraries.removeWorktree,
  getWorktrees: gitLibraries.getWorktrees,
}));

const { registerGitRoutes } = await import('./routes.js');

const createRouteRegistry = () => {
  const routes = new Map();

  return {
    app: {
      get(routePath, handler) {
        routes.set(`GET ${routePath}`, handler);
      },
      post(routePath, handler) {
        routes.set(`POST ${routePath}`, handler);
      },
      put(routePath, handler) {
        routes.set(`PUT ${routePath}`, handler);
      },
      delete(routePath, handler) {
        routes.set(`DELETE ${routePath}`, handler);
      },
    },
    getRoute(method, routePath) {
      return routes.get(`${method} ${routePath}`);
    },
  };
};

const createMockResponse = () => {
  let statusCode = 200;
  let body = null;

  return {
    status(code) {
      statusCode = code;
      return this;
    },
    json(payload) {
      body = payload;
      return this;
    },
    setHeader() { return this; },
    get statusCode() {
      return statusCode;
    },
    get body() {
      return body;
    },
  };
};

describe('git routes index mutations', () => {
  beforeEach(() => {
    gitLibraries.stageFiles.mockReset();
    gitLibraries.unstageFiles.mockReset();
    gitLibraries.createWorktree.mockReset();
    gitLibraries.removeWorktree.mockReset();
    gitLibraries.getWorktrees.mockReset();
  });

  it('accepts legacy stage path payloads', async () => {
    const { app, getRoute } = createRouteRegistry();
    registerGitRoutes(app);
    const response = createMockResponse();

    await getRoute('POST', '/api/git/stage')(
      { query: { directory: '/repo' }, body: { path: 'a.ts' } },
      response,
    );

    expect(response.statusCode).toBe(200);
    expect(gitLibraries.stageFiles).toHaveBeenCalledWith('/repo', ['a.ts']);
  });

  it('accepts bulk stage paths payloads', async () => {
    const { app, getRoute } = createRouteRegistry();
    registerGitRoutes(app);
    const response = createMockResponse();

    await getRoute('POST', '/api/git/stage')(
      { query: { directory: '/repo' }, body: { paths: ['a.ts', 'b.ts'] } },
      response,
    );

    expect(response.statusCode).toBe(200);
    expect(gitLibraries.stageFiles).toHaveBeenCalledWith('/repo', ['a.ts', 'b.ts']);
  });

  it('accepts legacy unstage path payloads', async () => {
    const { app, getRoute } = createRouteRegistry();
    registerGitRoutes(app);
    const response = createMockResponse();

    await getRoute('POST', '/api/git/unstage')(
      { query: { directory: '/repo' }, body: { path: 'a.ts' } },
      response,
    );

    expect(response.statusCode).toBe(200);
    expect(gitLibraries.unstageFiles).toHaveBeenCalledWith('/repo', ['a.ts']);
  });

  it('accepts bulk unstage paths payloads', async () => {
    const { app, getRoute } = createRouteRegistry();
    registerGitRoutes(app);
    const response = createMockResponse();

    await getRoute('POST', '/api/git/unstage')(
      { query: { directory: '/repo' }, body: { paths: ['a.ts', 'b.ts'] } },
      response,
    );

    expect(response.statusCode).toBe(200);
    expect(gitLibraries.unstageFiles).toHaveBeenCalledWith('/repo', ['a.ts', 'b.ts']);
  });

  it('rejects invalid path payloads before calling git', async () => {
    const { app, getRoute } = createRouteRegistry();
    registerGitRoutes(app);
    const response = createMockResponse();

    await getRoute('POST', '/api/git/stage')(
      { query: { directory: '/repo' }, body: { paths: [' ', null] } },
      response,
    );

    expect(response.statusCode).toBe(400);
    expect(response.body).toEqual({ error: 'path parameter is required' });
    expect(gitLibraries.stageFiles).not.toHaveBeenCalled();
  });
});

describe('git worktree queue lifecycle integration', () => {
  beforeEach(() => {
    gitLibraries.createWorktree.mockReset();
    gitLibraries.removeWorktree.mockReset();
    gitLibraries.getWorktrees.mockReset();
  });

  const createQueueService = () => ({
    getRuntimeKey: vi.fn(() => 'runtime-A'),
    getWorktreeLifecycle: vi.fn(() => ({ state: 'active', token: null })),
    markWorktreeActive: vi.fn(),
    prepareWorktreeDeletion: vi.fn(),
    commitWorktreeDeletion: vi.fn(),
    rollbackWorktreeDeletion: vi.fn(),
  });

  const registerWithQueue = (messageQueueService) => {
    const registry = createRouteRegistry();
    let requestNumber = 0;
    registerGitRoutes(registry.app, {
      messageQueueService,
      createRequestID: () => `request-${++requestNumber}`,
    });
    return registry;
  };

  const createDeferred = () => {
    let resolve;
    let reject;
    const promise = new Promise((resolvePromise, rejectPromise) => {
      resolve = resolvePromise;
      reject = rejectPromise;
    });
    return { promise, resolve, reject };
  };

  it('passes captured runtime keys through lifecycle options with allowlisted payloads', async () => {
    const rejectRuntimeKeyPayload = (result) => vi.fn(async (input, options) => {
      if (Object.hasOwn(input, 'runtimeKey')) {
        throw new Error('runtimeKey is outside the lifecycle payload allowlist');
      }
      if (options?.runtimeKey !== 'runtime-A') {
        throw new Error('missing captured runtime key');
      }
      return result;
    });
    const queue = {
      getRuntimeKey: vi.fn(() => 'runtime-A'),
      getWorktreeLifecycle: vi.fn(() => ({ state: 'deleting', token: 'repair-token' })),
      markWorktreeActive: rejectRuntimeKeyPayload(undefined),
      prepareWorktreeDeletion: rejectRuntimeKeyPayload({ token: 'deletion-token' }),
      commitWorktreeDeletion: rejectRuntimeKeyPayload(undefined),
      rollbackWorktreeDeletion: rejectRuntimeKeyPayload(undefined),
    };
    gitLibraries.createWorktree.mockResolvedValue({ path: '/created-worktree' });
    gitLibraries.getWorktrees.mockResolvedValue([{ path: '/created-worktree' }]);
    gitLibraries.removeWorktree.mockResolvedValue(true);
    const { getRoute } = registerWithQueue(queue);

    const createResponse = createMockResponse();
    await getRoute('POST', '/api/git/worktrees')(
      { query: { directory: '/repo' }, body: {} },
      createResponse,
    );

    const repairResponse = createMockResponse();
    await getRoute('POST', '/api/git/worktrees/queue-activation')(
      { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
      repairResponse,
    );

    const deleteResponse = createMockResponse();
    await getRoute('DELETE', '/api/git/worktrees')(
      { query: { directory: '/repo' }, body: { directory: '/created-worktree' } },
      deleteResponse,
    );

    expect(createResponse.statusCode).toBe(200);
    expect(repairResponse.statusCode).toBe(200);
    expect(deleteResponse.statusCode).toBe(200);
    expect(queue.markWorktreeActive).toHaveBeenCalledWith(
      { requestID: 'request-1', directory: '/created-worktree' },
      { runtimeKey: 'runtime-A' },
    );
    expect(queue.rollbackWorktreeDeletion).toHaveBeenCalledWith(
      { requestID: 'request-2', directory: '/created-worktree', token: 'repair-token' },
      { runtimeKey: 'runtime-A' },
    );
    expect(queue.prepareWorktreeDeletion).toHaveBeenCalledWith(
      { requestID: 'request-3', directory: '/created-worktree' },
      { runtimeKey: 'runtime-A' },
    );
    expect(queue.commitWorktreeDeletion).toHaveBeenCalledWith(
      { requestID: 'request-4', directory: '/created-worktree', projectDirectory: '/repo', token: 'deletion-token' },
      { runtimeKey: 'runtime-A' },
    );
  });

  it('activates the queue worktree after successful creation', async () => {
    const queue = createQueueService();
    let runtimeKey = 'runtime-A';
    queue.getRuntimeKey.mockImplementation(() => runtimeKey);
    gitLibraries.createWorktree.mockImplementation(async () => {
      runtimeKey = 'runtime-B';
      return { path: '/created-worktree' };
    });
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();

    await getRoute('POST', '/api/git/worktrees')(
      { query: { directory: '/repo' }, body: {} },
      response,
    );

    expect(queue.markWorktreeActive).toHaveBeenCalledWith({ requestID: 'request-1', directory: '/created-worktree' }, { runtimeKey: 'runtime-A' });
    expect(response.body).toEqual({ path: '/created-worktree' });
  });

  it('reports a recoverable partial failure when queue activation fails after creation', async () => {
    const queue = createQueueService();
    gitLibraries.createWorktree.mockResolvedValue({ path: '/created-worktree' });
    queue.markWorktreeActive.mockRejectedValue(new Error('queue unavailable'));
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();
    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      await getRoute('POST', '/api/git/worktrees')(
        { query: { directory: '/repo' }, body: {} },
        response,
      );
    } finally {
      errorLog.mockRestore();
    }

    expect(response.statusCode).toBe(503);
    expect(response.body).toEqual({
      code: 'message_queue_activation_pending',
      worktree: { path: '/created-worktree' },
      repair: {
        method: 'POST',
        path: '/api/git/worktrees/queue-activation',
        body: { projectDirectory: '/repo', directory: '/created-worktree' },
      },
    });
  });

  it('activates a worktree queue through the recovery route', async () => {
    const queue = createQueueService();
    let runtimeKey = 'runtime-A';
    queue.getRuntimeKey.mockImplementation(() => runtimeKey);
    gitLibraries.getWorktrees.mockImplementation(async () => {
      runtimeKey = 'runtime-B';
      return [{ path: '/created-worktree' }];
    });
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();

    await getRoute('POST', '/api/git/worktrees/queue-activation')(
      { body: { projectDirectory: ' /repo ', directory: ' /created-worktree ' } },
      response,
    );

    expect(gitLibraries.getWorktrees).toHaveBeenCalledWith('/repo');
    expect(queue.getWorktreeLifecycle).toHaveBeenCalledWith('/created-worktree', { runtimeKey: 'runtime-A' });
    expect(queue.markWorktreeActive).toHaveBeenCalledWith({ requestID: 'request-1', directory: '/created-worktree' }, { runtimeKey: 'runtime-A' });
    expect(response.body).toEqual({ directory: '/created-worktree', state: 'active' });
  });

  it('rolls back a persisted deleting lifecycle during activation recovery', async () => {
    const queue = createQueueService();
    queue.getWorktreeLifecycle.mockReturnValue({ state: 'deleting', token: 'deletion-token' });
    gitLibraries.getWorktrees.mockResolvedValue([{ path: '/created-worktree' }]);
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();

    await getRoute('POST', '/api/git/worktrees/queue-activation')(
      { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
      response,
    );

    expect(queue.getWorktreeLifecycle).toHaveBeenCalledWith('/created-worktree', { runtimeKey: 'runtime-A' });
    expect(queue.rollbackWorktreeDeletion).toHaveBeenCalledWith({ requestID: 'request-1', directory: '/created-worktree', token: 'deletion-token' }, { runtimeKey: 'runtime-A' });
    expect(queue.markWorktreeActive).not.toHaveBeenCalled();
    expect(response.body).toEqual({ directory: '/created-worktree', state: 'active' });
  });

  it('returns busy while activation recovery holds the worktree lifecycle lock', async () => {
    const queue = createQueueService();
    const rollback = createDeferred();
    queue.getWorktreeLifecycle.mockReturnValue({ state: 'deleting', token: 'deletion-token' });
    queue.rollbackWorktreeDeletion.mockReturnValue(rollback.promise);
    gitLibraries.getWorktrees.mockResolvedValue([{ path: '/created-worktree' }]);
    const { getRoute } = registerWithQueue(queue);
    const repairResponse = createMockResponse();
    const deleteResponse = createMockResponse();

    const repair = getRoute('POST', '/api/git/worktrees/queue-activation')(
      { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
      repairResponse,
    );
    await vi.waitFor(() => expect(queue.rollbackWorktreeDeletion).toHaveBeenCalledOnce());

    await getRoute('DELETE', '/api/git/worktrees')(
      { query: { directory: '/repo' }, body: { directory: '/created-worktree/' } },
      deleteResponse,
    );

    expect(deleteResponse.statusCode).toBe(409);
    expect(deleteResponse.body).toEqual({ code: 'worktree_lifecycle_busy' });
    rollback.resolve();
    await repair;
  });

  it('returns busy while deletion holds the worktree lifecycle lock', async () => {
    const queue = createQueueService();
    const prepare = createDeferred();
    queue.prepareWorktreeDeletion.mockReturnValue(prepare.promise);
    gitLibraries.getWorktrees.mockResolvedValue([{ path: '/worktree' }]);
    const { getRoute } = registerWithQueue(queue);
    const deleteResponse = createMockResponse();
    const repairResponse = createMockResponse();

    const deletion = getRoute('DELETE', '/api/git/worktrees')(
      { query: { directory: '/repo' }, body: { directory: '/worktree' } },
      deleteResponse,
    );
    await vi.waitFor(() => expect(queue.prepareWorktreeDeletion).toHaveBeenCalledOnce());

    await getRoute('POST', '/api/git/worktrees/queue-activation')(
      { body: { projectDirectory: '/repo', directory: '/worktree' } },
      repairResponse,
    );

    expect(repairResponse.statusCode).toBe(409);
    expect(repairResponse.body).toEqual({ code: 'worktree_lifecycle_busy' });
    prepare.resolve({ token: 'deletion-token' });
    gitLibraries.removeWorktree.mockResolvedValue(true);
    await deletion;
  });

  it('isolates lifecycle locks for identical paths in separate runtimes', async () => {
    const queue = createQueueService();
    const rollback = createDeferred();
    let runtimeKey = 'runtime-A';
    queue.getRuntimeKey.mockImplementation(() => runtimeKey);
    queue.getWorktreeLifecycle.mockImplementation((directory, { runtimeKey: key }) => key === 'runtime-A'
      ? { state: 'deleting', token: 'deletion-token' }
      : { state: 'active', token: null });
    queue.rollbackWorktreeDeletion.mockReturnValue(rollback.promise);
    gitLibraries.getWorktrees.mockResolvedValue([{ path: '/created-worktree' }]);
    const { getRoute } = registerWithQueue(queue);
    const firstResponse = createMockResponse();
    const secondResponse = createMockResponse();

    const firstRepair = getRoute('POST', '/api/git/worktrees/queue-activation')(
      { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
      firstResponse,
    );
    await vi.waitFor(() => expect(queue.rollbackWorktreeDeletion).toHaveBeenCalledOnce());
    runtimeKey = 'runtime-B';

    await getRoute('POST', '/api/git/worktrees/queue-activation')(
      { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
      secondResponse,
    );

    expect(secondResponse.body).toEqual({ directory: '/created-worktree', state: 'active' });
    expect(queue.markWorktreeActive).toHaveBeenCalledWith({ requestID: 'request-2', directory: '/created-worktree' }, { runtimeKey: 'runtime-B' });
    rollback.resolve();
    await firstRepair;
  });

  it('maps a failed deleting lifecycle rollback token to stale', async () => {
    const queue = createQueueService();
    queue.getWorktreeLifecycle.mockReturnValue({ state: 'deleting', token: 'deletion-token' });
    queue.rollbackWorktreeDeletion.mockRejectedValue(Object.assign(new Error('missing token'), { code: 'not_found' }));
    gitLibraries.getWorktrees.mockResolvedValue([{ path: '/created-worktree' }]);
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();
    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      await getRoute('POST', '/api/git/worktrees/queue-activation')(
        { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
        response,
      );
    } finally {
      errorLog.mockRestore();
    }

    expect(response.statusCode).toBe(409);
    expect(response.body).toEqual({ code: 'worktree_activation_stale' });
  });

  it('releases the lifecycle lock after an activation recovery error', async () => {
    const queue = createQueueService();
    queue.getWorktreeLifecycle.mockReturnValue({ state: 'deleting', token: 'deletion-token' });
    queue.rollbackWorktreeDeletion.mockRejectedValueOnce(new Error('queue unavailable'));
    gitLibraries.getWorktrees.mockResolvedValue([{ path: '/created-worktree' }]);
    const { getRoute } = registerWithQueue(queue);
    const firstResponse = createMockResponse();
    const secondResponse = createMockResponse();
    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      await getRoute('POST', '/api/git/worktrees/queue-activation')(
        { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
        firstResponse,
      );
      await getRoute('POST', '/api/git/worktrees/queue-activation')(
        { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
        secondResponse,
      );
    } finally {
      errorLog.mockRestore();
    }

    expect(firstResponse.statusCode).toBe(503);
    expect(secondResponse.body).toEqual({ directory: '/created-worktree', state: 'active' });
  });

  it('reports an unavailable queue service from the recovery route', async () => {
    const { app, getRoute } = createRouteRegistry();
    registerGitRoutes(app);
    const response = createMockResponse();

    await getRoute('POST', '/api/git/worktrees/queue-activation')(
      { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
      response,
    );

    expect(response.statusCode).toBe(501);
    expect(response.body).toEqual({ error: 'Message queue service is not available' });
  });

  it('reports a stale recovery target absent from the worktree catalog', async () => {
    const queue = createQueueService();
    gitLibraries.getWorktrees.mockResolvedValue([{ path: '/other-worktree' }]);
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();

    await getRoute('POST', '/api/git/worktrees/queue-activation')(
      { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
      response,
    );

    expect(response.statusCode).toBe(409);
    expect(response.body).toEqual({ code: 'worktree_activation_stale' });
    expect(queue.markWorktreeActive).not.toHaveBeenCalled();
  });

  it('reports a stale recovery target when queue deletion locks its scope', async () => {
    const queue = createQueueService();
    gitLibraries.getWorktrees.mockResolvedValue([{ path: '/created-worktree' }]);
    queue.markWorktreeActive.mockRejectedValue(Object.assign(new Error('scope locked'), { code: 'scope_locked' }));
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();
    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      await getRoute('POST', '/api/git/worktrees/queue-activation')(
        { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
        response,
      );
    } finally {
      errorLog.mockRestore();
    }

    expect(response.statusCode).toBe(409);
    expect(response.body).toEqual({ code: 'worktree_activation_stale' });
  });

  it('keeps queue activation repair retryable when the worktree catalog fails', async () => {
    const queue = createQueueService();
    gitLibraries.getWorktrees.mockRejectedValue(new Error('git unavailable'));
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();
    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      await getRoute('POST', '/api/git/worktrees/queue-activation')(
        { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
        response,
      );
    } finally {
      errorLog.mockRestore();
    }

    expect(response.statusCode).toBe(503);
    expect(response.body).toEqual({
      code: 'message_queue_activation_pending',
      repair: {
        method: 'POST',
        path: '/api/git/worktrees/queue-activation',
        body: { projectDirectory: '/repo', directory: '/created-worktree' },
      },
    });
    expect(queue.markWorktreeActive).not.toHaveBeenCalled();
  });

  it('reports a recoverable activation failure from the recovery route', async () => {
    const queue = createQueueService();
    gitLibraries.getWorktrees.mockResolvedValue([{ path: '/created-worktree' }]);
    queue.markWorktreeActive.mockRejectedValue(new Error('queue unavailable'));
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();
    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      await getRoute('POST', '/api/git/worktrees/queue-activation')(
        { body: { projectDirectory: '/repo', directory: '/created-worktree' } },
        response,
      );
    } finally {
      errorLog.mockRestore();
    }

    expect(response.statusCode).toBe(503);
    expect(response.body).toEqual({
      code: 'message_queue_activation_pending',
      repair: {
        method: 'POST',
        path: '/api/git/worktrees/queue-activation',
        body: { projectDirectory: '/repo', directory: '/created-worktree' },
      },
    });
  });

  it('validates the recovery route directory', async () => {
    const queue = createQueueService();
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();

    await getRoute('POST', '/api/git/worktrees/queue-activation')(
      { body: { projectDirectory: '/repo', directory: ' ' } },
      response,
    );

    expect(response.statusCode).toBe(400);
    expect(response.body).toEqual({ error: 'directory is required' });
    expect(queue.markWorktreeActive).not.toHaveBeenCalled();
  });

  it('prepares then commits queue deletion after git removal succeeds', async () => {
    const queue = createQueueService();
    let runtimeKey = 'runtime-A';
    queue.getRuntimeKey.mockImplementation(() => runtimeKey);
    queue.prepareWorktreeDeletion.mockResolvedValue({ token: 'deletion-token' });
    gitLibraries.removeWorktree.mockImplementation(async () => {
      runtimeKey = 'runtime-B';
      return true;
    });
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();

    await getRoute('DELETE', '/api/git/worktrees')(
      { query: { directory: '/repo' }, body: { directory: '/worktree' } },
      response,
    );

    expect(gitLibraries.removeWorktree).toHaveBeenCalledWith('/repo', { directory: '/worktree', deleteLocalBranch: false });
    expect(queue.prepareWorktreeDeletion).toHaveBeenCalledWith({ requestID: 'request-1', directory: '/worktree' }, { runtimeKey: 'runtime-A' });
    expect(queue.commitWorktreeDeletion).toHaveBeenCalledWith({ requestID: 'request-2', directory: '/worktree', projectDirectory: '/repo', token: 'deletion-token' }, { runtimeKey: 'runtime-A' });
    expect(response.body).toEqual({ success: true });
  });

  it('rolls back queue deletion when git removal throws', async () => {
    const queue = createQueueService();
    queue.prepareWorktreeDeletion.mockResolvedValue({ token: 'deletion-token' });
    gitLibraries.removeWorktree.mockRejectedValue(new Error('git removal failed'));
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();
    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      await getRoute('DELETE', '/api/git/worktrees')(
        { query: { directory: '/repo' }, body: { directory: '/worktree' } },
        response,
      );
    } finally {
      errorLog.mockRestore();
    }

    expect(queue.rollbackWorktreeDeletion).toHaveBeenCalledWith({ requestID: 'request-2', directory: '/worktree', token: 'deletion-token' }, { runtimeKey: 'runtime-A' });
    expect(response.statusCode).toBe(500);
  });

  it('rolls back queue deletion when git removal returns false', async () => {
    const queue = createQueueService();
    queue.prepareWorktreeDeletion.mockResolvedValue({ token: 'deletion-token' });
    gitLibraries.removeWorktree.mockResolvedValue(false);
    gitLibraries.getWorktrees.mockResolvedValue([{ path: '/worktree' }]);
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();

    await getRoute('DELETE', '/api/git/worktrees')(
      { query: { directory: '/repo' }, body: { directory: '/worktree' } },
      response,
    );

    expect(queue.rollbackWorktreeDeletion).toHaveBeenCalledWith({ requestID: 'request-2', directory: '/worktree', token: 'deletion-token' }, { runtimeKey: 'runtime-A' });
    expect(response.body).toEqual({ success: false });
  });

  it('commits a prior deleting lifecycle when git reports the worktree absent', async () => {
    const queue = createQueueService();
    queue.prepareWorktreeDeletion.mockResolvedValue({ token: 'existing-token', state: 'deleting' });
    gitLibraries.removeWorktree.mockResolvedValue(false);
    gitLibraries.getWorktrees.mockResolvedValue([{ path: '/other/' }]);
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();

    await getRoute('DELETE', '/api/git/worktrees')(
      { query: { directory: '/repo' }, body: { directory: '/worktree/' } },
      response,
    );

    expect(queue.commitWorktreeDeletion).toHaveBeenCalledWith({ requestID: 'request-2', directory: '/worktree/', projectDirectory: '/repo', token: 'existing-token' }, { runtimeKey: 'runtime-A' });
    expect(response.body).toEqual({ success: true });
  });

  it('stops before git removal when queue deletion preparation fails', async () => {
    const queue = createQueueService();
    queue.prepareWorktreeDeletion.mockRejectedValue(new Error('queue unavailable'));
    const { getRoute } = registerWithQueue(queue);
    const response = createMockResponse();
    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      await getRoute('DELETE', '/api/git/worktrees')(
        { query: { directory: '/repo' }, body: { directory: '/worktree' } },
        response,
      );
    } finally {
      errorLog.mockRestore();
    }

    expect(gitLibraries.removeWorktree).not.toHaveBeenCalled();
    expect(response.statusCode).toBe(500);
  });

  it('keeps existing worktree behavior when the queue service is unavailable', async () => {
    gitLibraries.removeWorktree.mockResolvedValue(true);
    const { app, getRoute } = createRouteRegistry();
    registerGitRoutes(app);
    const response = createMockResponse();

    await getRoute('DELETE', '/api/git/worktrees')(
      { query: { directory: '/repo' }, body: { directory: '/worktree' } },
      response,
    );

    expect(response.body).toEqual({ success: true });
  });
});
