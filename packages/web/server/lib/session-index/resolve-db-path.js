import path from 'node:path';

/**
 * Resolves the session index database path from options and a fallback data directory.
 *
 * @param {object} options
 * @param {string|null|undefined} options.sessionIndexDbPath - Explicit path, null to disable, undefined for default
 * @param {string} openchamberDataDir - Fallback directory when no explicit path is provided
 * @returns {string|null} Resolved database path, or null to disable the session index
 */
export const resolveSessionIndexDbPath = ({ sessionIndexDbPath } = {}, openchamberDataDir) => {
  if (sessionIndexDbPath === null) {
    return null;
  }
  if (typeof sessionIndexDbPath === 'string' && sessionIndexDbPath.trim().length > 0) {
    return sessionIndexDbPath;
  }
  if (typeof openchamberDataDir !== 'string' || openchamberDataDir.trim().length === 0) {
    return null;
  }
  return path.join(openchamberDataDir, 'session-index.sqlite');
};
