import { describe, expect, it, vi } from 'vitest';

import { registerSessionIndexRoutes } from './routes.js';

const registry = () => {
  const routes = new Map();
  return {
    app: {
      get: (path, handler) => routes.set(`GET ${path}`, handler),
      put: (path, handler) => routes.set(`PUT ${path}`, handler),
      post: (path, handler) => routes.set(`POST ${path}`, handler),
      delete: (path, handler) => routes.set(`DELETE ${path}`, handler),
    },
    route: (method, path) => routes.get(`${method} ${path}`),
  };
};

const response = () => ({
  statusCode: 200,
  body: undefined,
  status(code) { this.statusCode = code; return this; },
  json(body) { this.body = body; return this; },
  end() { return this; },
});

describe('session index routes', () => {
  it('returns deterministic unsupported state outside Electron', () => {
    const { app, route } = registry();
    registerSessionIndexRoutes(app, { sessionIndexService: null });
    const res = response();

    route('GET', '/api/openchamber/session-index')({}, res);

    expect(res.statusCode).toBe(501);
    expect(res.body).toMatchObject({ error: expect.stringContaining('unavailable') });
  });

  it('returns an Electron snapshot through the OpenChamber route', () => {
    const { app, route } = registry();
    const sessionIndexService = { snapshot: () => ({ directories: [{ directory: '/repo', sessions: [] }] }) };
    registerSessionIndexRoutes(app, { sessionIndexService });
    const res = response();

    route('GET', '/api/openchamber/session-index')({}, res);

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ available: true, directories: [{ directory: '/repo', sessions: [] }] });
  });

  it('writes a batch of directory snapshots in one request', () => {
    const { app, route } = registry();
    const replaceDirectories = vi.fn();
    registerSessionIndexRoutes(app, {
      sessionIndexService: {
        snapshot: () => ({ directories: [] }),
        replaceDirectories,
      },
    });
    const res = response();
    const directories = [{ directory: '/repo', sessions: [], cursor: null, hasMore: false }];

    route('PUT', '/api/openchamber/session-index/snapshot')({ body: { directories } }, res);

    expect(res.statusCode).toBe(204);
    expect(replaceDirectories).toHaveBeenCalledWith(directories);
  });

  it('starts server-side sync without issuing project requests from the UI', () => {
    const { app, route } = registry();
    const enqueue = vi.fn(() => ({ revision: 1, sync: { active: true }, directories: [] }));
    registerSessionIndexRoutes(app, {
      sessionIndexService: { snapshot: () => ({ directories: [] }) },
      sessionIndexSyncRuntime: { enqueue, snapshot: () => ({ revision: 0, directories: [] }) },
    });
    const res = response();

    route('POST', '/api/openchamber/session-index/sync')({ body: { directories: ['/repo/a', '/repo/b'] } }, res);

    expect(res.statusCode).toBe(202);
    expect(enqueue).toHaveBeenCalledWith(['/repo/a', '/repo/b']);
    expect(res.body).toMatchObject({ revision: 1, sync: { active: true } });
  });

  it('does not register a long-poll changes route', () => {
    const { app, route } = registry();
    registerSessionIndexRoutes(app, {
      sessionIndexService: { snapshot: () => ({ directories: [] }) },
      sessionIndexSyncRuntime: { snapshot: () => ({ revision: 2, directories: [] }) },
    });

    expect(route('GET', '/api/openchamber/session-index/changes')).toBeUndefined();
  });
});
