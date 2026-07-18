import { describe, expect, it, vi } from 'vitest';

import { registerScheduledTaskRoutes } from './routes.js';

const createRouteRegistry = () => {
  const routes = new Map();

  return {
    app: {
      get(path, handler) {
        routes.set(`GET ${path}`, handler);
      },
      post() {},
      put() {},
      delete() {},
    },
    getRoute(path) {
      return routes.get(`GET ${path}`);
    },
  };
};

const createResponse = () => {
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
    get statusCode() {
      return statusCode;
    },
    get body() {
      return body;
    },
  };
};

const registerListRoute = ({ projects, listScheduledTasks, settings = { projects } }) => {
  const { app, getRoute } = createRouteRegistry();
  registerScheduledTaskRoutes(app, {
    readSettingsFromDiskMigrated: async () => settings,
    sanitizeProjects: vi.fn((value) => value),
    projectConfigRuntime: { listScheduledTasks },
  });
  return getRoute('/api/openchamber/scheduled-tasks');
};

describe('global scheduled task list route', () => {
  it('returns an empty aggregate when settings are unavailable', async () => {
    const listScheduledTasks = vi.fn();
    const handler = registerListRoute({ settings: null, listScheduledTasks });
    const response = createResponse();

    await handler({}, response);

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({ tasks: [], failedProjectIds: [] });
    expect(listScheduledTasks).not.toHaveBeenCalled();
  });

  it('aggregates tasks from every configured project with project ownership', async () => {
    const listScheduledTasks = vi.fn(async (projectId) => (
      projectId === 'project-a' ? [{ id: 'daily' }] : [{ id: 'weekly' }]
    ));
    const handler = registerListRoute({
      projects: [{ id: 'project-a' }, { id: 'project-b' }],
      listScheduledTasks,
    });
    const response = createResponse();

    await handler({}, response);

    expect(listScheduledTasks).toHaveBeenCalledWith('project-a');
    expect(listScheduledTasks).toHaveBeenCalledWith('project-b');
    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      tasks: [
        { projectId: 'project-a', task: { id: 'daily' } },
        { projectId: 'project-b', task: { id: 'weekly' } },
      ],
      failedProjectIds: [],
    });
  });

  it('retains separate ownership for matching task ids', async () => {
    const handler = registerListRoute({
      projects: [{ id: 'project-a' }, { id: 'project-b' }],
      listScheduledTasks: async () => [{ id: 'shared-task' }],
    });
    const response = createResponse();

    await handler({}, response);

    expect(response.body.tasks).toEqual([
      { projectId: 'project-a', task: { id: 'shared-task' } },
      { projectId: 'project-b', task: { id: 'shared-task' } },
    ]);
  });

  it('returns completed project tasks when one project fails', async () => {
    const handler = registerListRoute({
      projects: [{ id: 'project-a' }, { id: 'project-b' }],
      listScheduledTasks: async (projectId) => {
        if (projectId === 'project-a') {
          throw new Error('disk failure');
        }
        return [{ id: 'weekly' }];
      },
    });
    const response = createResponse();

    await handler({}, response);

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      tasks: [{ projectId: 'project-b', task: { id: 'weekly' } }],
      failedProjectIds: ['project-a'],
    });
  });
});
