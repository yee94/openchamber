import { createOpencodeClient } from '@opencode-ai/sdk/v2';

// --- error classification ---

const isTransportError = (error) => {
  if (!error) return true;
  if (error.name === 'TypeError' || error.name === 'FetchError' || error.name === 'AbortError') return true;
  const code = error.cause?.code || error.code;
  if (code === 'ECONNREFUSED' || code === 'ENOTFOUND' || code === 'ECONNRESET' || code === 'ETIMEDOUT' || code === 'EPIPE') return true;
  return false;
};

const isRetryableHttpStatus = (status) => {
  if (!Number.isFinite(status)) return true;
  return status === 408 || status === 429 || status >= 500;
};

const isAmbiguousPromptError = (_error, response) => {
  if (!response) return true;
  const status = response?.status;
  if (!Number.isFinite(status)) return true;
  return isRetryableHttpStatus(status);
};

// --- safe error messages (no paths/urls/secrets leaked to client) ---

const CLIENT_SAFE_ERRORS = {
  create: 'Failed to create session',
  prompt: 'Failed to submit prompt',
  internal: 'Internal server error',
};

const safeErrorMessage = (phase) =>
  CLIENT_SAFE_ERRORS[phase] || CLIENT_SAFE_ERRORS.internal;

// --- safe markUserMessageSent wrapper ---

const safeMark = (markUserMessageSent, sessionID, logger) => {
  if (typeof markUserMessageSent !== 'function' || !sessionID) return;
  try {
    markUserMessageSent(sessionID);
  } catch (err) {
    logger?.warn?.('[conversations] markUserMessageSent failed:', err?.message ?? err);
  }
};

// --- internal bounded timeout signals ---

const CREATE_TIMEOUT_MS = 30_000;
const PROMPT_TIMEOUT_MS = 45_000;
const READY_TIMEOUT_MS = 6_000;
const READY_POLL_MS = 75;

const timeoutSignal = (ms) => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  timer.unref?.();
  return { signal: controller.signal, clear: () => clearTimeout(timer) };
};

// --- main service ---

export const createConversationsService = (deps) => {
  const {
    buildOpenCodeUrl,
    getOpenCodeAuthHeaders,
    markUserMessageSent,
    waitForOpenCodeReady,
    logger = console,
  } = deps;

  const ensureClient = async () => {
    if (typeof waitForOpenCodeReady === 'function') {
      const t = timeoutSignal(READY_TIMEOUT_MS);
      try {
        await waitForOpenCodeReady(READY_TIMEOUT_MS, READY_POLL_MS);
      } catch (_err) {
        logger.warn('[conversations] waitForOpenCodeReady failed');
        return { error: 'openCodeNotReady' };
      } finally {
        t.clear();
      }
    }

    const baseUrl = buildOpenCodeUrl('/', '').replace(/\/$/, '');
    const authHeaders = getOpenCodeAuthHeaders();
    return createOpencodeClient({ baseUrl, headers: authHeaders });
  };

  const createAndPrompt = async ({ sanitizedInput } = {}) => {
    const clientOrError = await ensureClient();
    if (clientOrError?.error) {
      return {
        ok: false,
        phase: 'create',
        error: safeErrorMessage('create'),
      };
    }
    const client = clientOrError;

    // Phase 1: create session (30s timeout)
    let sessionResult;
    let upstreamStatus;
    const createT = timeoutSignal(CREATE_TIMEOUT_MS);
    try {
      sessionResult = await client.session.create({
        directory: sanitizedInput.directory,
        ...(sanitizedInput.title ? { title: sanitizedInput.title } : {}),
        ...(sanitizedInput.parentID ? { parentID: sanitizedInput.parentID } : {}),
        ...(sanitizedInput.metadata ? { metadata: sanitizedInput.metadata } : {}),
      }, {
        signal: createT.signal,
      });
    } catch (error) {
      logger.warn('[conversations] session.create transport error');
      return {
        ok: false,
        phase: 'create',
        error: safeErrorMessage('create'),
      };
    } finally {
      createT.clear();
    }

    upstreamStatus = sessionResult?.response?.status;

    if (sessionResult.error) {
      logger.warn(`[conversations] session.create SDK error (${upstreamStatus || 'no status'})`);
      return {
        ok: false,
        phase: 'create',
        error: safeErrorMessage('create'),
        ...(Number.isFinite(upstreamStatus) ? { status: upstreamStatus } : {}),
      };
    }

    const sessionID = sessionResult?.data?.id;
    if (!sessionID) {
      logger.warn('[conversations] session.create returned no session ID');
      return {
        ok: false,
        phase: 'create',
        error: safeErrorMessage('create'),
      };
    }

    const session = sessionResult?.data;

    // Phase 2: promptAsync (45s timeout, 204, does not wait for model completion)
    let promptResult;
    const promptT = timeoutSignal(PROMPT_TIMEOUT_MS);
    try {
      promptResult = await client.session.promptAsync({
        sessionID,
        directory: sanitizedInput.directory,
        messageID: sanitizedInput.messageID,
        model: {
          providerID: sanitizedInput.model.providerID,
          modelID: sanitizedInput.model.modelID,
        },
        ...(sanitizedInput.agent ? { agent: sanitizedInput.agent } : {}),
        ...(sanitizedInput.variant ? { variant: sanitizedInput.variant } : {}),
        parts: sanitizedInput.parts,
      }, {
        signal: promptT.signal,
      });
    } catch (error) {
      const ambiguous = isTransportError(error);
      logger.warn(`[conversations] promptAsync throw (ambiguous=${ambiguous})`);
      if (ambiguous) {
        safeMark(markUserMessageSent, sessionID, logger);
      }
      return {
        ok: false,
        phase: 'prompt',
        session,
        messageID: sanitizedInput.messageID,
        ambiguous,
        error: safeErrorMessage('prompt'),
      };
    } finally {
      promptT.clear();
    }

    // SDK result shape { data, error, response }
    if (promptResult.error) {
      const httpStatus = promptResult.response?.status;
      const ambiguous = isAmbiguousPromptError(promptResult.error, promptResult.response);
      logger.warn(`[conversations] promptAsync SDK error (${httpStatus || 'no status'}, ambiguous=${ambiguous})`);
      if (ambiguous) {
        safeMark(markUserMessageSent, sessionID, logger);
      }
      return {
        ok: false,
        phase: 'prompt',
        session,
        messageID: sanitizedInput.messageID,
        ambiguous,
        error: safeErrorMessage('prompt'),
        ...(Number.isFinite(httpStatus) ? { status: httpStatus } : {}),
      };
    }

    // promptAsync 204 success
    safeMark(markUserMessageSent, sessionID, logger);

    return {
      ok: true,
      session,
      messageID: sanitizedInput.messageID,
    };
  };

  return {
    createAndPrompt,
  };
};
