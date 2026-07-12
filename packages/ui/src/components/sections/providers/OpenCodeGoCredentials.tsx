import React from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { toast } from '@/components/ui';
import { useI18n } from '@/lib/i18n';
import { runtimeFetch } from '@/lib/runtime-fetch';

interface CredentialStatus {
  configured: boolean;
  workspaceId?: string;
  authCookieMasked?: string;
}

export const OpenCodeGoCredentials: React.FC = () => {
  const { t } = useI18n();
  const [status, setStatus] = React.useState<CredentialStatus | null>(null);
  const [workspaceId, setWorkspaceId] = React.useState('');
  const [authCookie, setAuthCookie] = React.useState('');
  const [busy, setBusy] = React.useState<'save' | 'validate' | 'delete' | null>(null);
  const workspaceInputRef = React.useRef<HTMLInputElement>(null);
  const cookieInputRef = React.useRef<HTMLInputElement>(null);

  React.useEffect(() => {
    const loadStatus = async () => {
      try {
        const response = await runtimeFetch('/api/quota/credentials/opencode-go');
        if (!response.ok) throw new Error('load failed');
        const next = await response.json() as CredentialStatus;
        setStatus(next);
        setWorkspaceId(next.workspaceId ?? '');
      } catch {
        setStatus({ configured: false });
      }
    };
    void loadStatus();
  }, []);

  const save = async () => {
    const submittedWorkspaceId = workspaceInputRef.current?.value.trim() ?? workspaceId.trim();
    const submittedAuthCookie = cookieInputRef.current?.value.trim() ?? authCookie.trim();
    setBusy('save');
    try {
      const response = await runtimeFetch('/api/quota/credentials/opencode-go', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ workspaceId: submittedWorkspaceId, authCookie: submittedAuthCookie }),
      });
      const payload = await response.json().catch(() => null);
      if (!response.ok) throw new Error(payload?.error);
      setStatus(payload);
      setAuthCookie('');
      toast.success(t('settings.providers.page.openCodeGo.saved'));
    } catch (error) {
      const message = error instanceof Error ? error.message : '';
      toast.error(message || t('settings.providers.page.openCodeGo.saveFailed'));
    } finally { setBusy(null); }
  };

  const validate = async () => {
    setBusy('validate');
    try {
      const response = await runtimeFetch('/api/quota/credentials/opencode-go/validate', { method: 'POST' });
      const payload = await response.json().catch(() => null);
      if (!response.ok) throw new Error(payload?.error || t('settings.providers.page.openCodeGo.invalid'));
      toast.success(t('settings.providers.page.openCodeGo.valid'));
    } catch (error) {
      const message = error instanceof Error ? error.message : '';
      toast.error(message || t('settings.providers.page.openCodeGo.invalid'));
    } finally { setBusy(null); }
  };

  const remove = async () => {
    setBusy('delete');
    try {
      const response = await runtimeFetch('/api/quota/credentials/opencode-go', { method: 'DELETE' });
      if (!response.ok) throw new Error('delete failed');
      setStatus({ configured: false });
      setWorkspaceId('');
      setAuthCookie('');
      toast.success(t('settings.providers.page.openCodeGo.deleted'));
    } catch {
      toast.error(t('settings.providers.page.openCodeGo.deleteFailed'));
    } finally { setBusy(null); }
  };

  return (
    <div data-settings-item="providers.opencode-go-credentials" className="mb-8">
      <div className="mb-1 px-1">
        <h3 className="typography-ui-header font-medium text-foreground">{t('settings.providers.page.openCodeGo.title')}</h3>
        <p className="typography-meta text-muted-foreground">{t('settings.providers.page.openCodeGo.description')}</p>
      </div>
      <section className="space-y-3 px-2 pb-2 pt-0">
        <label className="block typography-ui-label text-foreground">
          {t('settings.providers.page.openCodeGo.workspaceId')}
          <Input ref={workspaceInputRef} className="mt-1 h-7 font-mono text-xs" value={workspaceId} onChange={(event) => setWorkspaceId(event.target.value)} placeholder="wrk_..." />
        </label>
        <label className="block typography-ui-label text-foreground">
          {t('settings.providers.page.openCodeGo.authCookie')}
          <Input ref={cookieInputRef} className="mt-1 h-7 font-mono text-xs" type="password" autoComplete="off" value={authCookie} onChange={(event) => setAuthCookie(event.target.value)} placeholder={status?.authCookieMasked ?? 'auth=...'} />
        </label>
        <p className="typography-meta text-muted-foreground">{t('settings.providers.page.openCodeGo.help')}</p>
        <div className="flex flex-wrap gap-2">
          <Button size="xs" onClick={save} disabled={Boolean(busy)}>{status?.configured ? t('settings.providers.page.openCodeGo.replace') : t('settings.providers.page.openCodeGo.save')}</Button>
          {status?.configured && <Button variant="outline" size="xs" onClick={validate} disabled={Boolean(busy)}>{t('settings.providers.page.openCodeGo.validate')}</Button>}
          {status?.configured && <Button variant="destructive" size="xs" onClick={remove} disabled={Boolean(busy)}>{t('settings.providers.page.openCodeGo.delete')}</Button>}
        </div>
      </section>
    </div>
  );
};
