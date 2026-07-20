const unsupported = (res) => res.status(501).json({ error: 'Session index is unavailable for this runtime' });

export const registerSessionIndexRoutes = (app, { sessionIndexService, sessionIndexSyncRuntime }) => {
  app.get('/api/openchamber/session-index', (_req, res) => {
    if (!sessionIndexService) return unsupported(res);
    res.json({
      available: true,
      ...(sessionIndexSyncRuntime?.snapshot() ?? sessionIndexService.snapshot()),
    });
  });

  app.post('/api/openchamber/session-index/sync', (req, res) => {
    if (!sessionIndexSyncRuntime) return unsupported(res);
    const directories = Array.isArray(req.body?.directories) ? req.body.directories : [];
    res.status(202).json(sessionIndexSyncRuntime.enqueue(directories));
  });

  app.put('/api/openchamber/session-index/directory', (req, res) => {
    if (!sessionIndexService) return unsupported(res);
    try {
      sessionIndexService.replaceDirectory(req.body ?? {});
      res.status(204).end();
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : 'Invalid session index payload' });
    }
  });

  app.put('/api/openchamber/session-index/snapshot', (req, res) => {
    if (!sessionIndexService) return unsupported(res);
    try {
      sessionIndexService.replaceDirectories(req.body?.directories);
      res.status(204).end();
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : 'Invalid session index payload' });
    }
  });

  app.post('/api/openchamber/session-index/session', (req, res) => {
    if (!sessionIndexService) return unsupported(res);
    res.status(sessionIndexService.upsert(req.body?.session) ? 204 : 400).end();
  });

  app.delete('/api/openchamber/session-index/session/:sessionId', (req, res) => {
    if (!sessionIndexService) return unsupported(res);
    sessionIndexService.remove(req.params.sessionId);
    res.status(204).end();
  });
};
