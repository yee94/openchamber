export default async function scheduledTaskPlugin() {
  const bridgeOrigin = process.env.OPENCHAMBER_SCHEDULED_TASK_BRIDGE_ORIGIN;
  const bridgePath = process.env.OPENCHAMBER_SCHEDULED_TASK_BRIDGE_PATH;
  const bridgeToken = process.env.OPENCHAMBER_SCHEDULED_TASK_BRIDGE_TOKEN;
  const operations = ['list', 'create', 'update', 'delete', 'run'];

  const requestSchema = {
    type: 'object',
    required: ['operation'],
    additionalProperties: false,
    properties: {
      operation: { type: 'string', enum: operations, description: 'list, create, update, delete, or run' },
      taskId: { type: 'string', description: 'Task id for update, delete, or run' },
      name: { type: 'string', description: 'Task name' },
      enabled: { type: 'boolean', description: 'false pauses a task; true resumes it' },
      schedule: {
        type: 'object',
        description: 'Schedule with kind daily, weekly, once, or cron. weekdays uses 0=Sunday through 6=Saturday.',
        additionalProperties: false,
        properties: {
          kind: { type: 'string', enum: ['daily', 'weekly', 'once', 'cron'] },
          time: { type: 'string', description: 'Local HH:MM time for daily or weekly schedules' },
          weekdays: { type: 'array', items: { type: 'integer', minimum: 0, maximum: 6 } },
          at: { type: 'string', description: 'ISO timestamp for once schedules' },
          expression: { type: 'string', description: 'Cron expression for cron schedules' },
          timezone: { type: 'string' },
        },
      },
      execution: {
        type: 'object',
        description: 'Scheduled prompt and optional model. The current session model is the default.',
        additionalProperties: true,
        properties: { prompt: { type: 'string' }, model: { type: 'string' } },
      },
    },
  };

  const addDefaultAsk = (permission) => {
    if (typeof permission === 'undefined') return { scheduled_task: 'ask' };
    if (typeof permission === 'string') return permission;
    if (!permission || typeof permission !== 'object' || Array.isArray(permission)) return permission;
    if (Object.prototype.hasOwnProperty.call(permission, 'scheduled_task') || Object.prototype.hasOwnProperty.call(permission, '*')) {
      return permission;
    }
    return { ...permission, scheduled_task: 'ask' };
  };

  return {
    config: async (config) => {
      config.permission = addDefaultAsk(config.permission);
    },
    tool: {
      scheduled_task: {
        description: 'Manage OpenChamber scheduled tasks. Schedules support daily, weekly, once, and cron; weekdays uses 0=Sunday. The current session model is the execution default. Update with enabled:false pauses and enabled:true resumes.',
        args: { request: requestSchema },
        execute: async (args, context) => {
          const request = args?.request;
          const operation = request?.operation;
          if (!operations.includes(operation)) throw new Error('scheduled_task requires a supported request.operation');
          if (!bridgeOrigin || !bridgePath || !bridgeToken) throw new Error('scheduled_task bridge is unavailable');
          if (['create', 'update', 'delete', 'run'].includes(operation)) {
            await context.ask({
              permission: 'scheduled_task',
              patterns: [operation],
              always: [operation],
              metadata: { operation, taskId: request.taskId || null },
            });
          }
          const { operation: _operation, ...input } = request;
          const payload = {
            operation,
            context: {
              sessionID: context.sessionID,
              messageID: context.messageID,
              directory: context.directory,
              worktree: context.worktree,
              agent: context.agent,
            },
            input,
          };
          let response;
          try {
            response = await fetch(new URL(bridgePath, bridgeOrigin), {
              method: 'POST',
              headers: { 'content-type': 'application/json', 'x-openchamber-scheduled-task-token': bridgeToken },
              body: JSON.stringify(payload),
            });
          } catch (error) {
            throw new Error(`scheduled_task bridge request failed: ${error instanceof Error ? error.message : String(error)}`);
          }
          const body = await response.json().catch(() => ({}));
          if (!response.ok) {
            const safeError = typeof body?.error === 'string' && body.error.trim() ? body.error.trim() : 'Scheduled task request failed';
            throw new Error(`scheduled_task bridge responded with ${response.status}: ${safeError}`);
          }
          try {
            return JSON.stringify(body);
          } catch {
            return '{}';
          }
        },
      },
    },
  };
}
