import { WebSocketServer } from 'ws';

import { parseRequestPathname } from '../terminal/index.js';
import {
  MESSAGE_STREAM_DIRECTORY_WS_PATH,
  MESSAGE_STREAM_GLOBAL_WS_PATH,
  MESSAGE_STREAM_WS_HEARTBEAT_INTERVAL_MS,
  sendMessageStreamWsEvent,
  sendMessageStreamWsFrame,
} from './protocol.js';
import { createGlobalMessageStreamHub } from './global-hub.js';
import {
  DEFAULT_UPSTREAM_RECONNECT_DELAY_MS,
  DEFAULT_UPSTREAM_STALL_TIMEOUT_MS,
  createUpstreamSseReader,
} from './upstream-reader.js';

function shouldTriggerUpstreamHealthCheck(upstream) {
  if (!upstream) {
    return true;
  }

  if (!upstream.body) {
    return upstream.ok || upstream.status >= 500;
  }

  return upstream.status >= 500;
}

export function createGlobalUiEventBroadcaster({
  sseClients,
  wsClients,
  writeSseEvent,
}) {
  return (payload, options = {}) => {
    const hasSseClients = sseClients.size > 0;
    const hasWsClients = wsClients.size > 0;
    if (!hasSseClients && !hasWsClients) {
      return;
    }

    if (hasSseClients) {
      for (const res of sseClients) {
        try {
          writeSseEvent(res, payload);
        } catch {
        }
      }
    }

    if (hasWsClients) {
      for (const socket of Array.from(wsClients)) {
        const sent = sendMessageStreamWsEvent(socket, payload, {
          directory: typeof options.directory === 'string' && options.directory.length > 0 ? options.directory : 'global',
          eventId: typeof options.eventId === 'string' && options.eventId.length > 0 ? options.eventId : undefined,
        });
        if (!sent) {
          wsClients.delete(socket);
        }
      }
    }
  };
}

export function createMessageStreamWsRuntime({
  server,
  uiAuthController,
  isRequestOriginAllowed,
  rejectWebSocketUpgrade,
  buildOpenCodeUrl,
  getOpenCodeAuthHeaders,
  processForwardedEventPayload,
  wsClients,
  triggerHealthCheck,
  heartbeatIntervalMs = MESSAGE_STREAM_WS_HEARTBEAT_INTERVAL_MS,
  upstreamStallTimeoutMs = DEFAULT_UPSTREAM_STALL_TIMEOUT_MS,
  upstreamReconnectDelayMs = DEFAULT_UPSTREAM_RECONNECT_DELAY_MS,
  fetchImpl = fetch,
  globalEventHub = null,
}) {
  const wsServer = new WebSocketServer({
    noServer: true,
  });

  const ownsGlobalHub = !globalEventHub;
  const globalHub = globalEventHub ?? createGlobalMessageStreamHub({
    buildOpenCodeUrl,
    getOpenCodeAuthHeaders,
    fetchImpl,
    upstreamStallTimeoutMs,
    upstreamReconnectDelayMs,
  });

  const globalClients = new Set();
  const globalClientLastEventIds = new Map();
  const globalReadyClients = new Set();

  const replayGlobalEvents = (socket, requestedLastEventId) => {
    for (const entry of globalHub.replayAfter(requestedLastEventId)) {
      const sent = sendMessageStreamWsEvent(socket, entry.payload, {
        directory: entry.directory,
        eventId: entry.eventId,
      });
      if (!sent) {
        globalClients.delete(socket);
        globalClientLastEventIds.delete(socket);
        globalReadyClients.delete(socket);
        wsClients.delete(socket);
        return;
      }
    }
  };

  const markGlobalClientReady = (socket, requestedLastEventId) => {
    if (socket.readyState !== 1) {
      return;
    }

    const sent = sendMessageStreamWsFrame(socket, {
      type: 'ready',
      scope: 'global',
    });
    if (!sent) {
      globalClients.delete(socket);
      globalClientLastEventIds.delete(socket);
      globalReadyClients.delete(socket);
      wsClients.delete(socket);
      return;
    }

    globalReadyClients.add(socket);
    wsClients.add(socket);
    replayGlobalEvents(socket, requestedLastEventId);
  };

  const closeGlobalClientsWithInitialError = ({ message, closeReason = message, triggerHealthCheckFor = null }) => {
    for (const socket of Array.from(globalClients)) {
      sendMessageStreamWsFrame(socket, { type: 'error', message });
      try {
        socket.close(1011, closeReason);
      } catch {
      }
      globalClients.delete(socket);
      globalClientLastEventIds.delete(socket);
      globalReadyClients.delete(socket);
      wsClients.delete(socket);
    }

    if (triggerHealthCheckFor === true || (triggerHealthCheckFor && shouldTriggerUpstreamHealthCheck(triggerHealthCheckFor))) {
      triggerHealthCheck?.();
    }

    if (ownsGlobalHub) {
      globalHub.stop();
    }
  };

  const unsubscribeGlobalEvent = globalHub.subscribeEvent(({ envelope, payload, directory, eventId }) => {
    for (const socket of Array.from(globalClients)) {
      if (!globalReadyClients.has(socket)) {
        continue;
      }
      const sent = sendMessageStreamWsEvent(socket, payload, {
        directory,
        eventId,
      });
      if (!sent) {
        globalClients.delete(socket);
        globalClientLastEventIds.delete(socket);
        globalReadyClients.delete(socket);
        wsClients.delete(socket);
      }
    }

    processForwardedEventPayload(payload, (syntheticPayload) => {
      for (const socket of Array.from(globalClients)) {
        if (!globalReadyClients.has(socket)) {
          continue;
        }
        const sent = sendMessageStreamWsEvent(socket, syntheticPayload, { directory: 'global' });
        if (!sent) {
          globalClients.delete(socket);
          globalClientLastEventIds.delete(socket);
          globalReadyClients.delete(socket);
          wsClients.delete(socket);
        }
      }
    });
  });

  const unsubscribeGlobalStatus = globalHub.subscribeStatus((status) => {
    if (status.type === 'connect') {
      for (const socket of Array.from(globalClients)) {
        if (!globalReadyClients.has(socket)) {
          markGlobalClientReady(socket, globalClientLastEventIds.get(socket) ?? '');
        }
      }
      return;
    }

    if (status.type === 'initial-error') {
      const error = status.error;
      if (error?.type === 'upstream_unavailable') {
        closeGlobalClientsWithInitialError({
          message: `OpenCode event stream unavailable (${error.status})`,
          closeReason: 'OpenCode event stream unavailable',
          triggerHealthCheckFor: error.response,
        });
        return;
      }

      closeGlobalClientsWithInitialError({
        message: status.buildUrlFailed ? 'OpenCode service unavailable' : 'Failed to connect to OpenCode event stream',
        closeReason: status.buildUrlFailed ? 'OpenCode service unavailable' : 'Failed to connect to OpenCode event stream',
        triggerHealthCheckFor: !status.buildUrlFailed,
      });
      return;
    }

    if (status.type === 'error' && status.error?.type === 'stream_error') {
      console.warn('Message stream WS proxy error:', status.error.error);
    }
  });

  const stopGlobalHubIfUnused = () => {
    if (ownsGlobalHub && globalClients.size === 0) {
      globalHub.stop();
    }
  };

  wsServer.on('connection', (socket, req) => {
    const rawUrl = typeof req?.url === 'string' ? req.url : MESSAGE_STREAM_GLOBAL_WS_PATH;
    const pathname = parseRequestPathname(rawUrl);
    const requestUrl = new URL(rawUrl, 'http://127.0.0.1');
    const isGlobalStream = pathname === MESSAGE_STREAM_GLOBAL_WS_PATH;
    const requestedLastEventId = requestUrl.searchParams.get('lastEventId')?.trim() || '';
    const requestedDirectory = requestUrl.searchParams.get('directory')?.trim() || '';

    if (isGlobalStream) {
      const pingInterval = setInterval(() => {
        if (socket.readyState !== 1) {
          return;
        }

        try {
          socket.ping();
        } catch {
        }
      }, heartbeatIntervalMs);

      const heartbeatInterval = setInterval(() => {
        if (!globalHub.isConnected()) {
          return;
        }

        sendMessageStreamWsEvent(socket, { type: 'openchamber:heartbeat', timestamp: Date.now() }, { directory: 'global' });
      }, heartbeatIntervalMs);

      socket.on('close', () => {
        clearInterval(pingInterval);
        clearInterval(heartbeatInterval);
        globalClients.delete(socket);
        globalClientLastEventIds.delete(socket);
        globalReadyClients.delete(socket);
        wsClients.delete(socket);
        stopGlobalHubIfUnused();
      });

      socket.on('error', () => {
        void 0;
      });

      globalClients.add(socket);
      globalClientLastEventIds.set(socket, requestedLastEventId);
      globalHub.start();
      if (globalHub.isConnected()) {
        markGlobalClientReady(socket, requestedLastEventId);
      }
      return;
    }

    const controller = new AbortController();
    let upstreamConnected = false;
    let streamReady = false;
    let reader = null;
    const cleanup = () => {
      if (!controller.signal.aborted) {
        controller.abort();
      }
      reader?.stop();
      wsClients.delete(socket);
    };

    const pingInterval = setInterval(() => {
      if (socket.readyState !== 1) {
        return;
      }

      try {
        socket.ping();
      } catch {
      }
    }, heartbeatIntervalMs);

    const heartbeatInterval = setInterval(() => {
      if (!upstreamConnected) {
        return;
      }

      sendMessageStreamWsEvent(socket, { type: 'openchamber:heartbeat', timestamp: Date.now() }, { directory: 'global' });
    }, heartbeatIntervalMs);

    socket.on('close', () => {
      clearInterval(pingInterval);
      clearInterval(heartbeatInterval);
      upstreamConnected = false;
      cleanup();
    });

    socket.on('error', () => {
      void 0;
    });

    const run = async () => {
      const forwardEvent = ({ envelope, payload }) => {
        const directory = isGlobalStream
          ? (typeof envelope?.directory === 'string' && envelope.directory.length > 0 ? envelope.directory : 'global')
          : (requestedDirectory || envelope?.directory || 'global');

        sendMessageStreamWsEvent(socket, payload, {
          directory,
          eventId: typeof envelope?.eventId === 'string' && envelope.eventId.length > 0 ? envelope.eventId : undefined,
        });

        processForwardedEventPayload(payload, (syntheticPayload) => {
          sendMessageStreamWsEvent(socket, syntheticPayload, { directory: 'global' });
        });
      };

      try {
        let buildUrlFailed = false;
        const closeWithInitialError = ({ message, closeReason = message, triggerHealthCheckFor = null }) => {
          sendMessageStreamWsFrame(socket, { type: 'error', message });
          socket.close(1011, closeReason);
          if (triggerHealthCheckFor === true || (triggerHealthCheckFor && shouldTriggerUpstreamHealthCheck(triggerHealthCheckFor))) {
            triggerHealthCheck?.();
          }
          reader?.stop();
          cleanup();
        };

        reader = createUpstreamSseReader({
          initialLastEventId: requestedLastEventId,
          signal: controller.signal,
          stallTimeoutMs: upstreamStallTimeoutMs,
          reconnectDelayMs: upstreamReconnectDelayMs,
          fetchImpl,
          buildUrl: () => {
            buildUrlFailed = false;
            let targetUrl;
            try {
              targetUrl = new URL(buildOpenCodeUrl('/event', ''));
            } catch {
              buildUrlFailed = true;
              throw new Error('OpenCode service unavailable');
            }

            if (requestedDirectory) {
              targetUrl.searchParams.set('directory', requestedDirectory);
            }

            return targetUrl;
          },
          getHeaders: getOpenCodeAuthHeaders,
          onConnect() {
            if (!streamReady) {
              sendMessageStreamWsFrame(socket, {
                type: 'ready',
                scope: 'directory',
              });
              streamReady = true;
            }

            upstreamConnected = true;
          },
          onDisconnect() {
            upstreamConnected = false;
          },
          onEvent: forwardEvent,
          onError(error) {
            if (controller.signal.aborted) {
              return;
            }

            if (!streamReady) {
              if (error?.type === 'upstream_unavailable') {
                closeWithInitialError({
                  message: `OpenCode event stream unavailable (${error.status})`,
                  closeReason: 'OpenCode event stream unavailable',
                  triggerHealthCheckFor: error.response,
                });
                return;
              }

              closeWithInitialError({
                message: buildUrlFailed ? 'OpenCode service unavailable' : 'Failed to connect to OpenCode event stream',
                closeReason: buildUrlFailed ? 'OpenCode service unavailable' : 'Failed to connect to OpenCode event stream',
                triggerHealthCheckFor: !buildUrlFailed,
              });
              return;
            }

            if (error?.type === 'stream_error') {
              console.warn('Message stream WS proxy error:', error.error);
            }
          },
        });

        await reader.start();
      } catch (error) {
        if (!controller.signal.aborted) {
          console.warn('Message stream WS proxy error:', error);
          sendMessageStreamWsFrame(socket, { type: 'error', message: 'Message stream proxy error' });
          socket.close(1011, 'Message stream proxy error');
        }
      } finally {
        cleanup();
        try {
          if (socket.readyState === 1 || socket.readyState === 0) {
            socket.close();
          }
        } catch {
        }
      }
    };

    void run();
  });

  const upgradeHandler = (req, socket, head) => {
    const pathname = parseRequestPathname(req.url);
    if (pathname !== MESSAGE_STREAM_GLOBAL_WS_PATH && pathname !== MESSAGE_STREAM_DIRECTORY_WS_PATH) {
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

  return {
    wsServer,
    async close() {
      server.off('upgrade', upgradeHandler);
      unsubscribeGlobalEvent();
      unsubscribeGlobalStatus();
      if (ownsGlobalHub) {
        globalHub.stop();
      }

      try {
        for (const client of wsServer.clients) {
          try {
            client.terminate();
          } catch {
          }
        }

        await new Promise((resolve) => {
          wsServer.close(() => resolve());
        });
      } catch {
      } finally {
        wsClients.clear();
      }
    },
  };
}
