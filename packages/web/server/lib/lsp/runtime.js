import { WebSocketServer } from 'ws';

import { createLspProcessManager } from './process-manager.js';

const LSP_WS_PATH = '/api/lsp/ws';
const LSP_WS_MAX_PAYLOAD_BYTES = 2 * 1024 * 1024;
const LSP_WS_HEARTBEAT_INTERVAL_MS = 30000;

const parseRequestUrl = (url) => {
  try {
    return new URL(url, 'http://localhost');
  } catch {
    return null;
  }
};

export function createLspRuntime({
  server,
  uiAuthController,
  isRequestOriginAllowed,
  rejectWebSocketUpgrade,
  processManager = createLspProcessManager(),
}) {
  const wsServer = new WebSocketServer({
    noServer: true,
    maxPayload: LSP_WS_MAX_PAYLOAD_BYTES,
  });

  wsServer.on('connection', (socket, request) => {
    const parsed = parseRequestUrl(request.url);
    const directory = parsed?.searchParams.get('directory') ?? '';

    let handle;
    try {
      handle = processManager.acquire(directory);
    } catch (error) {
      try {
        socket.close(1008, error instanceof Error ? error.message : 'invalid directory');
      } catch {
        // ignore
      }
      return;
    }

    const unsubscribe = handle.subscribe((message) => {
      if (socket.readyState !== 1) {
        return;
      }
      try {
        socket.send(message);
      } catch {
        // socket is going away
      }
    });

    const heartbeatInterval = setInterval(() => {
      if (socket.readyState !== 1) {
        return;
      }
      try {
        socket.ping();
      } catch {
        // ignore
      }
    }, LSP_WS_HEARTBEAT_INTERVAL_MS);

    socket.on('message', (raw, isBinary) => {
      if (isBinary) {
        return;
      }
      const text = typeof raw === 'string' ? raw : raw.toString('utf8');
      if (!text.trim()) {
        return;
      }
      try {
        handle.send(text);
      } catch {
        try {
          socket.close(1011, 'language server stdin closed');
        } catch {
          // ignore
        }
      }
    });

    const cleanup = () => {
      clearInterval(heartbeatInterval);
      unsubscribe();
      handle.release();
    };

    socket.on('close', cleanup);
    socket.on('error', () => {
      // close follows
    });
  });

  const upgradeHandler = (req, socket, head) => {
    const parsed = parseRequestUrl(req.url);
    if (parsed?.pathname !== LSP_WS_PATH) {
      return;
    }

    const handleUpgrade = async () => {
      try {
        if (uiAuthController?.enabled) {
          const sessionToken = await uiAuthController?.ensureSessionToken?.(req, null);
          if (!sessionToken) {
            rejectWebSocketUpgrade(socket, 401, 'UI authentication required');
            return;
          }

          const originAllowed = await isRequestOriginAllowed(req);
          if (!originAllowed) {
            rejectWebSocketUpgrade(socket, 403, 'Invalid origin');
            return;
          }
        }

        wsServer.handleUpgrade(req, socket, head, (ws) => {
          wsServer.emit('connection', ws, req);
        });
      } catch {
        rejectWebSocketUpgrade(socket, 500, 'Upgrade failed');
      }
    };

    void handleUpgrade();
  };

  server.on('upgrade', upgradeHandler);

  const stop = () => {
    server.off('upgrade', upgradeHandler);
    for (const client of wsServer.clients) {
      try {
        client.close(1001, 'server shutting down');
      } catch {
        // ignore
      }
    }
    try {
      wsServer.close();
    } catch {
      // ignore
    }
    processManager.stop();
  };

  return { stop };
}
