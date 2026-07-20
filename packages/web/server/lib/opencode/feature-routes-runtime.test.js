import fs from 'node:fs/promises';
import { describe, expect, it } from 'vitest';

describe('feature routes runtime composition', () => {
  it('registers the managed scheduled-task tool route with its required dependencies', async () => {
    const source = await fs.readFile(new URL('./feature-routes-runtime.js', import.meta.url), 'utf8');
    expect(source).toContain("import { registerScheduledTaskToolRoute } from '../scheduled-tasks/managed-tool-route.js';");
    expect(source).toMatch(/const \{[\s\S]*express,[\s\S]*\} = routeDependencies;/);
    expect(source).toMatch(/registerScheduledTaskToolRoute\(app, \{[\s\S]*express,[\s\S]*validateDirectoryPath,[\s\S]*scheduledTasksRuntime,/);
  });

  it('registers message queue routes with the injected service before proxy composition', async () => {
    const source = await fs.readFile(new URL('./feature-routes-runtime.js', import.meta.url), 'utf8');
    expect(source).toContain("import { registerMessageQueueRoutes } from '../message-queue/routes.js';");
    expect(source).toMatch(/const \{[\s\S]*messageQueueService,[\s\S]*\} = routeDependencies;/);
    expect(source).toContain('registerMessageQueueRoutes(app, { messageQueueService, messageQueueRuntime });');
  });
});
