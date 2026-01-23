import React from 'react';
import { Button } from '@/components/ui/button';
import { toast } from 'sonner';
import { getRegisteredRuntimeAPIs } from '@/contexts/runtimeAPIRegistry';
import { RiGithubFill } from '@remixicon/react';

type GitHubUser = {
  login: string;
  id?: number;
  avatarUrl?: string;
  name?: string;
  email?: string;
};

type AuthStatusResponse = {
  connected: boolean;
  user?: GitHubUser | null;
  scope?: string;
  error?: string;
};

type DeviceFlowStartResponse = {
  deviceCode: string;
  userCode: string;
  verificationUri: string;
  verificationUriComplete?: string;
  expiresIn: number;
  interval: number;
  scope?: string;
};

type DeviceFlowCompleteResponse =
  | { connected: true; user: GitHubUser; scope?: string }
  | { connected: false; status?: string; error?: string };

export const GitHubSettings: React.FC = () => {
  const runtimeGitHub = getRegisteredRuntimeAPIs()?.github;

  const openExternal = React.useCallback(async (url: string) => {
    if (typeof window === 'undefined') {
      return;
    }

    const desktop = (window as typeof window & { opencodeDesktop?: { openExternal?: (url: string) => Promise<unknown> } }).opencodeDesktop;
    if (desktop?.openExternal) {
      try {
        await desktop.openExternal(url);
        return;
      } catch {
        // fall through
      }
    }

    try {
      window.open(url, '_blank', 'noopener,noreferrer');
    } catch {
      // ignore
    }
  }, []);

  const [isLoading, setIsLoading] = React.useState(true);
  const [isBusy, setIsBusy] = React.useState(false);
  const [status, setStatus] = React.useState<AuthStatusResponse | null>(null);
  const [flow, setFlow] = React.useState<DeviceFlowStartResponse | null>(null);
  const [pollIntervalMs, setPollIntervalMs] = React.useState<number | null>(null);
  const pollTimerRef = React.useRef<number | null>(null);

  const stopPolling = React.useCallback(() => {
    if (pollTimerRef.current != null) {
      window.clearInterval(pollTimerRef.current);
      pollTimerRef.current = null;
    }
    setPollIntervalMs(null);
  }, []);

  const refreshStatus = React.useCallback(async () => {
    if (runtimeGitHub) {
      const payload = await runtimeGitHub.authStatus();
      setStatus(payload as AuthStatusResponse);
      return payload as AuthStatusResponse;
    }

    const response = await fetch('/api/github/auth/status', {
      method: 'GET',
      headers: { Accept: 'application/json' },
    });
    const payload = (await response.json().catch(() => null)) as AuthStatusResponse | null;
    if (!response.ok || !payload) {
      throw new Error(payload?.error || response.statusText || 'Failed to load GitHub status');
    }
    setStatus(payload);
    return payload;
  }, [runtimeGitHub]);

  React.useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        await refreshStatus();
      } catch (error) {
        console.warn('Failed to load GitHub auth status:', error);
      } finally {
        if (mounted) setIsLoading(false);
      }
    })();
    return () => {
      mounted = false;
      stopPolling();
    };
  }, [refreshStatus, stopPolling]);

  const startConnect = React.useCallback(async () => {
    setIsBusy(true);
    try {
      const payload = runtimeGitHub
        ? await runtimeGitHub.authStart()
        : await (async () => {
            const response = await fetch('/api/github/auth/start', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Accept: 'application/json',
              },
              body: JSON.stringify({}),
            });
            const body = (await response.json().catch(() => null)) as DeviceFlowStartResponse | { error?: string } | null;
            if (!response.ok || !body || !('deviceCode' in body)) {
              throw new Error((body as { error?: string } | null)?.error || response.statusText);
            }
            return body;
          })();

      setFlow(payload);
      setPollIntervalMs(Math.max(1, payload.interval) * 1000);

      const url = payload.verificationUriComplete || payload.verificationUri;
      void openExternal(url);
    } catch (error) {
      console.error('Failed to start GitHub connect:', error);
      toast.error('Failed to start GitHub connect');
    } finally {
      setIsBusy(false);
    }
  }, [openExternal, runtimeGitHub]);

  const pollOnce = React.useCallback(async (deviceCode: string) => {
    if (runtimeGitHub) {
      return runtimeGitHub.authComplete(deviceCode) as Promise<DeviceFlowCompleteResponse>;
    }

    const response = await fetch('/api/github/auth/complete', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({ deviceCode }),
    });

    const payload = (await response.json().catch(() => null)) as DeviceFlowCompleteResponse | { error?: string } | null;
    if (!response.ok || !payload) {
      throw new Error((payload as { error?: string } | null)?.error || response.statusText);
    }
    return payload as DeviceFlowCompleteResponse;
  }, [runtimeGitHub]);

  React.useEffect(() => {
    if (!flow?.deviceCode || !pollIntervalMs) {
      return;
    }
    if (pollTimerRef.current != null) {
      return;
    }

    pollTimerRef.current = window.setInterval(() => {
      void (async () => {
        try {
          const result = await pollOnce(flow.deviceCode);
          if (result.connected) {
            toast.success('GitHub connected');
            setFlow(null);
            stopPolling();
            await refreshStatus();
            return;
          }

          if (result.status === 'slow_down') {
            setPollIntervalMs((prev) => (prev ? prev + 5000 : 5000));
          }

          if (result.status === 'expired_token' || result.status === 'access_denied') {
            toast.error(result.error || 'GitHub authorization failed');
            setFlow(null);
            stopPolling();
          }
        } catch (error) {
          console.warn('GitHub polling failed:', error);
        }
      })();
    }, pollIntervalMs);

    return () => {
      if (pollTimerRef.current != null) {
        window.clearInterval(pollTimerRef.current);
        pollTimerRef.current = null;
      }
    };
  }, [flow, pollIntervalMs, pollOnce, refreshStatus, stopPolling]);

  const disconnect = React.useCallback(async () => {
    setIsBusy(true);
    try {
      stopPolling();
      setFlow(null);
      if (runtimeGitHub) {
        await runtimeGitHub.authDisconnect();
      } else {
        const response = await fetch('/api/github/auth', {
          method: 'DELETE',
          headers: { Accept: 'application/json' },
        });
        if (!response.ok) {
          throw new Error(response.statusText);
        }
      }
      toast.success('GitHub disconnected');
      await refreshStatus();
    } catch (error) {
      console.error('Failed to disconnect GitHub:', error);
      toast.error('Failed to disconnect GitHub');
    } finally {
      setIsBusy(false);
    }
  }, [refreshStatus, stopPolling, runtimeGitHub]);

  if (isLoading) {
    return null;
  }

  const connected = Boolean(status?.connected);
  const user = status?.user;

  return (
    <div className="space-y-6">
      <div className="space-y-1">
        <h3 className="typography-ui-header font-semibold text-foreground">GitHub</h3>
        <p className="typography-meta text-muted-foreground">
          Connect a GitHub account for in-app PR and issue workflows.
        </p>
      </div>

      {connected ? (
        <div className="flex items-center justify-between gap-4 rounded-lg border bg-background/50 px-4 py-3">
          <div className="flex min-w-0 items-center gap-4">
            {user?.avatarUrl ? (
              <img
                src={user.avatarUrl}
                alt={user.login ? `${user.login} avatar` : 'GitHub avatar'}
                className="h-14 w-14 shrink-0 rounded-full border border-border/60 bg-muted object-cover"
                loading="lazy"
                referrerPolicy="no-referrer"
              />
            ) : (
              <div className="h-14 w-14 shrink-0 rounded-full border border-border/60 bg-muted" />
            )}

            <div className="min-w-0">
              <div className="typography-ui-header font-semibold text-foreground truncate">
                {user?.name?.trim() || user?.login || 'GitHub'}
              </div>
              {user?.email ? (
                <div className="typography-body text-muted-foreground truncate">{user.email}</div>
              ) : null}
              <div className="mt-1 flex items-center gap-2 typography-meta text-muted-foreground truncate">
                <RiGithubFill className="h-4 w-4" />
                <span className="font-mono">{user?.login || 'unknown'}</span>
              </div>
              {status?.scope ? (
                <div className="typography-micro text-muted-foreground truncate">Scopes: {status.scope}</div>
              ) : null}
            </div>
          </div>

          <Button variant="outline" onClick={disconnect} disabled={isBusy}>
            Disconnect
          </Button>
        </div>
      ) : (
        <div className="flex items-center justify-between gap-3 rounded-lg border bg-background/50 px-3 py-2">
          <div className="typography-ui-label text-foreground">Not connected</div>
          <Button onClick={startConnect} disabled={isBusy}>
            Connect
          </Button>
        </div>
      )}

      {flow ? (
        <div className="space-y-3 rounded-lg border bg-background/50 p-3">
          <div className="space-y-1">
            <div className="typography-ui-label text-foreground">Authorize OpenChamber</div>
            <div className="typography-meta text-muted-foreground">
              In GitHub, enter this code:
            </div>
          </div>
          <div className="flex items-center justify-between gap-3">
            <div className="font-mono text-lg tracking-widest text-foreground">{flow.userCode}</div>
            <Button variant="outline" asChild>
              <a
                href={flow.verificationUriComplete || flow.verificationUri}
                target="_blank"
                rel="noopener noreferrer"
              >
                Open GitHub
              </a>
            </Button>
          </div>
          <div className="typography-micro text-muted-foreground">
            Waiting for approval… (auto-refresh)
          </div>
          <div className="flex justify-end">
            <Button variant="ghost" disabled={isBusy} onClick={() => {
              stopPolling();
              setFlow(null);
            }}>
              Cancel
            </Button>
          </div>
        </div>
      ) : null}
    </div>
  );
};
