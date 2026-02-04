import React from 'react';
import { RiFileCopyLine, RiCheckLine, RiExternalLinkLine } from '@remixicon/react';
import { isDesktopShell, isTauriShell } from '@/lib/desktop';

const INSTALL_COMMAND = 'curl -fsSL https://opencode.ai/install | bash';
const POLL_INTERVAL_MS = 3000;

type OnboardingScreenProps = {
  onCliAvailable?: () => void;
};

function BashCommand({ onCopy }: { onCopy: () => void }) {
  return (
    <div className="flex items-center justify-center gap-3">
      <code>
        <span style={{ color: 'var(--syntax-keyword)' }}>curl</span>
        <span className="text-muted-foreground"> -fsSL </span>
        <span style={{ color: 'var(--syntax-string)' }}>https://opencode.ai/install</span>
        <span className="text-muted-foreground"> | </span>
        <span style={{ color: 'var(--syntax-keyword)' }}>bash</span>
      </code>
      <button
        onClick={onCopy}
        className="inline-flex items-center text-muted-foreground hover:text-foreground transition-colors"
        title="Copy to clipboard"
      >
        <RiFileCopyLine className="h-4 w-4" />
      </button>
    </div>
  );
}

const HINT_DELAY_MS = 30000;

export function OnboardingScreen({ onCliAvailable }: OnboardingScreenProps) {
  const [copied, setCopied] = React.useState(false);
  const [showHint, setShowHint] = React.useState(false);
  const [isDesktopApp, setIsDesktopApp] = React.useState(false);
  const [isRetrying, setIsRetrying] = React.useState(false);

  React.useEffect(() => {
    const timer = setTimeout(() => setShowHint(true), HINT_DELAY_MS);
    return () => clearTimeout(timer);
  }, []);

  React.useEffect(() => {
    setIsDesktopApp(isDesktopShell());
  }, []);

  const handleDragStart = React.useCallback(async (e: React.MouseEvent) => {
    if ((e.target as HTMLElement).closest('button, a, input, select, textarea, code')) {
      return;
    }
    if (e.button !== 0) return;
    if (isDesktopApp && isTauriShell()) {
      try {
        const { getCurrentWindow } = await import('@tauri-apps/api/window');
        const window = getCurrentWindow();
        await window.startDragging();
      } catch (error) {
        console.error('Failed to start window dragging:', error);
      }
    }
  }, [isDesktopApp]);

  const checkCliAvailability = React.useCallback(async (): Promise<boolean> => {
    try {
      const response = await fetch('/health');
      if (!response.ok) return false;
      const data = await response.json();
      return data.openCodeRunning === true || data.isOpenCodeReady === true;
    } catch {
      return false;
    }
  }, []);

  const handleRetry = React.useCallback(async () => {
    setIsRetrying(true);
    try {
      await fetch('/api/config/reload', { method: 'POST' });
    } finally {
      setTimeout(() => setIsRetrying(false), 1000);
    }
  }, []);

  const handleCopy = React.useCallback(async () => {
    try {
      await navigator.clipboard.writeText(INSTALL_COMMAND);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  }, []);

  React.useEffect(() => {
    const poll = async () => {
      const available = await checkCliAvailability();
      if (available) {
        onCliAvailable?.();
      }
    };

    const interval = setInterval(poll, POLL_INTERVAL_MS);
    poll();

    return () => clearInterval(interval);
  }, [checkCliAvailability, onCliAvailable]);

  return (
    <div
      className="h-full flex items-center justify-center bg-transparent p-8 relative cursor-default select-none"
      onMouseDown={handleDragStart}
    >
      <div className="w-full space-y-4 text-center">
        <div className="space-y-4">
          <h1 className="text-3xl font-semibold tracking-tight text-foreground">
            Welcome to OpenChamber
          </h1>
          <p className="text-muted-foreground">
            <a
              href="https://opencode.ai"
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary hover:underline inline-flex items-center gap-1"
            >
              OpenCode CLI
              <RiExternalLinkLine className="h-4 w-4" />
            </a>
            {' '}is required to continue.
          </p>
        </div>

        <div className="flex justify-center">
          <div className="bg-background/60 backdrop-blur-sm border border-border rounded-lg px-5 py-3 font-mono text-sm w-fit">
            {copied ? (
              <div className="flex items-center justify-center gap-2" style={{ color: 'var(--status-success)' }}>
                <RiCheckLine className="h-4 w-4" />
                Copied to clipboard
              </div>
            ) : (
              <BashCommand onCopy={handleCopy} />
            )}
          </div>
        </div>

        <a
          href="https://opencode.ai/docs"
          target="_blank"
          rel="noopener noreferrer"
          className="text-sm text-muted-foreground hover:text-foreground transition-colors inline-flex items-center gap-1 justify-center"
        >
          View documentation
          <RiExternalLinkLine className="h-3 w-3" />
        </a>

        <p className="text-sm text-muted-foreground animate-pulse">
          Waiting for OpenCode installation...
        </p>

        <div className="flex justify-center">
          <button
            type="button"
            onClick={handleRetry}
            disabled={isRetrying}
            className="text-sm text-muted-foreground hover:text-foreground transition-colors"
          >
            {isRetrying ? 'Retrying…' : 'Retry'}
          </button>
        </div>
      </div>

      {showHint && (
        <div className="absolute bottom-8 left-0 right-0 text-center space-y-1">
          <p className="text-sm text-muted-foreground/70">
            Already installed? Make sure <code className="text-foreground/70">opencode</code> is in your PATH
          </p>
          <p className="text-sm text-muted-foreground/70">
            or set <code className="text-foreground/70">OPENCODE_BINARY</code> environment variable.
          </p>
        </div>
      )}
    </div>
  );
}
