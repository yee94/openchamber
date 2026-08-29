import { getRuntimeUrlResolver } from '@/lib/runtime-url';
import { refreshRuntimeUrlAuthToken } from '@/lib/runtime-auth';
import { openRuntimeWebSocket } from '@/lib/relay/runtime-socket';
import type { RelayTunnelWebSocket } from '@/lib/relay/tunnel-client';

export type LspJsonTransport = {
  send(message: string): void;
  subscribe(handler: (message: string) => void): void;
  unsubscribe(handler: (message: string) => void): void;
  close(): void;
  ready: Promise<void>;
};

const CONNECT_TIMEOUT_MS = 12_000;

export const createLspWebSocketTransport = (directory: string): LspJsonTransport => {
  const handlers = new Set<(message: string) => void>();
  const outbound: string[] = [];
  let socket: RelayTunnelWebSocket | null = null;
  let closed = false;

  const flush = () => {
    if (!socket || socket.readyState !== WebSocket.OPEN) {
      return;
    }
    while (outbound.length > 0) {
      const next = outbound.shift();
      if (next) {
        socket.send(next);
      }
    }
  };

  const ready = (async () => {
    try {
      await refreshRuntimeUrlAuthToken();
    } catch {
      // Local unauthenticated runtime.
    }

    if (closed) {
      throw new Error('language server transport closed');
    }

    const url = getRuntimeUrlResolver().websocket('/api/lsp/ws', { directory });
    const nextSocket = openRuntimeWebSocket(url);
    socket = nextSocket;

    await new Promise<void>((resolve, reject) => {
      const timeout = window.setTimeout(() => {
        reject(new Error('language server connection timed out'));
      }, CONNECT_TIMEOUT_MS);

      nextSocket.onopen = () => {
        window.clearTimeout(timeout);
        flush();
        resolve();
      };
      nextSocket.onerror = () => {
        window.clearTimeout(timeout);
        reject(new Error('language server socket error'));
      };
      nextSocket.onclose = () => {
        window.clearTimeout(timeout);
        if (!closed) {
          reject(new Error('language server socket closed'));
        }
      };
    });

    nextSocket.onmessage = (event) => {
      const text = typeof event.data === 'string' ? event.data : '';
      if (!text) {
        return;
      }
      for (const handler of handlers) {
        handler(text);
      }
    };
  })();

  return {
    send(message) {
      if (closed) {
        throw new Error('language server transport closed');
      }
      outbound.push(message);
      flush();
    },
    subscribe(handler) {
      handlers.add(handler);
    },
    unsubscribe(handler) {
      handlers.delete(handler);
    },
    close() {
      closed = true;
      handlers.clear();
      outbound.length = 0;
      try {
        socket?.close();
      } catch {
        // ignore
      }
      socket = null;
    },
    ready,
  };
};
