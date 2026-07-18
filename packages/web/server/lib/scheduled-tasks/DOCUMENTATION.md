# Scheduled Tasks module

Server-owned scheduled task runtime and routes for OpenChamber-only automation.

## Scope

- Per-project scheduled task persistence is owned by `packages/web/server/lib/projects/project-config.js`.
- Runtime orchestration and execution is owned by this module.
- This module is OpenChamber feature logic; it is intentionally separate from OpenCode proxy/runtime internals.

## Files

- `packages/web/server/lib/scheduled-tasks/runtime.js`
  - Next-run computation (daily/weekly/cron compatibility)
  - Timer scheduling and queueing
  - Concurrency controls
  - Session create + prompt_async execution
  - Emits OpenChamber task-run events

- `packages/web/server/lib/scheduled-tasks/routes.js`
  - Global scheduled task list endpoint with per-project partial-result handling
  - Project scheduled task CRUD endpoints
  - Manual run endpoint
  - OpenChamber events SSE stream endpoint

- `packages/web/server/lib/scheduled-tasks/managed-tool-route.js`
  - Managed OpenCode `scheduled_task` bridge endpoint
  - Resolves the authoritative OpenCode session and message model before selecting
    the deepest configured project containing the session directory
  - Requires `validateDirectoryPath` for realpath-backed directory validation
    across request context, OpenCode session context, worktrees, and projects
  - Exports `registerScheduledTaskToolRoute(app, dependencies)`

- `packages/web/server/lib/scheduled-tasks/managed-tool-contract.js`
  - Exports `MANAGED_SCHEDULED_TASK_TOOL_PATH`
  - Exports `MANAGED_SCHEDULED_TASK_TOKEN_HEADER`

## Public exports (runtime.js)

- `createScheduledTasksRuntime(dependencies)`
- Returned API:
  - `start()`
  - `stop()`
  - `syncAllProjects()`
  - `syncProject(projectId)`
  - `runNow(projectId, taskId)`

## Public exports (routes.js)

- `registerScheduledTaskRoutes(app, dependencies)`
- Registers:
  - `GET /api/openchamber/scheduled-tasks`
  - `GET /api/projects/:projectId/scheduled-tasks`
  - `PUT /api/projects/:projectId/scheduled-tasks`
  - `DELETE /api/projects/:projectId/scheduled-tasks/:taskId`
  - `POST /api/projects/:projectId/scheduled-tasks/:taskId/run`
  - `GET /api/openchamber/scheduled-tasks/status`
  - `GET /api/openchamber/events`

## Global task list contract

`GET /api/openchamber/scheduled-tasks` reads configured projects through
`readSettingsFromDiskMigrated()` and `sanitizeProjects(settings.projects)`, then
loads each project with `projectConfigRuntime.listScheduledTasks(project.id)`.

The response is `{ tasks, failedProjectIds }`, where every task entry has the
shape `{ projectId, task }`. Task IDs are project-scoped, so entries retain their
`projectId` even when multiple projects contain the same task ID. A project load
failure preserves tasks from completed projects and adds that project ID to
`failedProjectIds`; settings-read failures return HTTP 500.
