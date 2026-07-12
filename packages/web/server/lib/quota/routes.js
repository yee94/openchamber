import express from 'express';
import {
  deleteOpenCodeGoCredential,
  getOpenCodeGoCredentialStatus,
  normalizeOpenCodeGoCredential,
  readOpenCodeGoCredential,
  writeOpenCodeGoCredential,
} from './opencode-go-credentials.js';
import { fetchOpenCodeGoUsage } from './providers/opencode-go.js';

export function registerQuotaRoutes(app, { getQuotaProviders }) {
  app.get('/api/quota/providers', async (_req, res) => {
    try {
      const { listConfiguredQuotaProviders } = await getQuotaProviders();
      const providers = listConfiguredQuotaProviders();
      res.json({ providers });
    } catch (error) {
      console.error('Failed to list quota providers:', error);
      res.status(500).json({ error: error.message || 'Failed to list quota providers' });
    }
  });

  app.get('/api/quota/credentials/opencode-go', (_req, res) => {
    res.json(getOpenCodeGoCredentialStatus());
  });

  app.put('/api/quota/credentials/opencode-go', express.json({ limit: '16kb' }), async (req, res) => {
    try {
      const credential = normalizeOpenCodeGoCredential(req.body);
      if (!credential) return res.status(400).json({ error: 'Workspace ID and auth cookie are required' });
      await fetchOpenCodeGoUsage(credential);
      res.json(writeOpenCodeGoCredential(credential));
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : 'Credential validation failed' });
    }
  });

  app.post('/api/quota/credentials/opencode-go/validate', async (_req, res) => {
    try {
      const credential = readOpenCodeGoCredential();
      if (!credential) return res.status(404).json({ error: 'Not configured' });
      await fetchOpenCodeGoUsage(credential);
      res.json({ valid: true });
    } catch (error) {
      res.status(400).json({ valid: false, error: error instanceof Error ? error.message : 'Credential validation failed' });
    }
  });

  app.delete('/api/quota/credentials/opencode-go', (_req, res) => {
    deleteOpenCodeGoCredential();
    res.json({ configured: false });
  });

  app.get('/api/quota/:providerId', async (req, res) => {
    try {
      const { providerId } = req.params;
      if (!providerId) {
        return res.status(400).json({ error: 'Provider ID is required' });
      }
      const { fetchQuotaForProvider } = await getQuotaProviders();
      const result = await fetchQuotaForProvider(providerId);
      res.json(result);
    } catch (error) {
      console.error('Failed to fetch quota:', error);
      res.status(500).json({ error: error.message || 'Failed to fetch quota' });
    }
  });
}
