import crypto from 'node:crypto';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

const SCHEMA_VERSION = 4;
const MAX_ROOT_SESSIONS = 20;

const normalizeDirectory = (value) => {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().replace(/\\/g, '/').replace(/\/+$/, '');
  return normalized || null;
};

const toTimestamp = (value) => (typeof value === 'number' && Number.isFinite(value) ? Math.trunc(value) : 0);

const toBooleanInt = (value) => (value ? 1 : 0);

const runtimeKeyFor = (runtimeConfig) => {
  const source = typeof runtimeConfig?.apiBaseUrl === 'string' && runtimeConfig.apiBaseUrl.trim()
    ? runtimeConfig.apiBaseUrl.trim()
    : 'local-managed-opencode';
  return crypto.createHash('sha256').update(source).digest('hex');
};

const toSummary = (session, fallbackDirectory) => {
  if (!session || typeof session.id !== 'string' || !session.id) return null;
  const directory = normalizeDirectory(session.directory ?? session.project?.worktree ?? fallbackDirectory);
  if (!directory) return null;
  return {
    id: session.id,
    directory,
    title: typeof session.title === 'string' ? session.title : '',
    createdAt: toTimestamp(session.time?.created),
    updatedAt: toTimestamp(session.time?.updated),
    archivedAt: toTimestamp(session.time?.archived),
    parentID: typeof session.parentID === 'string' ? session.parentID : null,
    hasChildren: typeof session.hasChildren === 'boolean' ? session.hasChildren : null,
  };
};

export const createSessionIndexService = ({ dbPath, getRuntimeConfig = () => null } = {}) => {
  if (typeof dbPath !== 'string' || !dbPath.trim()) return null;

  const Database = require('better-sqlite3');
  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  const existingTables = new Set(db.prepare(`
    SELECT name FROM sqlite_master
    WHERE type = 'table' AND name IN ('session_index_meta', 'runtime_directory', 'session_summary', 'session_child')
  `).all().map((row) => row.name));
  const hasMetaTable = existingTables.has('session_index_meta');
  const storedSchemaVersion = hasMetaTable
    ? Number(db.prepare("SELECT value FROM session_index_meta WHERE key = 'schema_version'").get()?.value)
    : 0;
  if (existingTables.size > 0 && storedSchemaVersion !== SCHEMA_VERSION) {
    // This database is only an acceleration index. Schema changes deliberately
    // rebuild from OpenCode instead of carrying migration compatibility code.
    db.exec(`
      DROP TABLE IF EXISTS session_summary;
      DROP TABLE IF EXISTS session_child;
      DROP TABLE IF EXISTS runtime_directory;
      DROP TABLE IF EXISTS session_index_meta;
    `);
  }
  db.exec(`
    CREATE TABLE IF NOT EXISTS session_index_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS runtime_directory (
      runtime_key TEXT NOT NULL,
      directory TEXT NOT NULL,
      cursor INTEGER,
      has_more INTEGER NOT NULL DEFAULT 0,
      last_synced_at INTEGER NOT NULL DEFAULT 0,
      last_full_synced_at INTEGER NOT NULL DEFAULT 0,
      last_accessed_at INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (runtime_key, directory)
    );
    CREATE TABLE IF NOT EXISTS session_summary (
      runtime_key TEXT NOT NULL,
      directory TEXT NOT NULL,
      session_id TEXT NOT NULL,
      title TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      archived_at INTEGER NOT NULL DEFAULT 0,
      parent_id TEXT,
      has_children INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (runtime_key, directory, session_id),
      FOREIGN KEY (runtime_key, directory)
        REFERENCES runtime_directory(runtime_key, directory)
        ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS session_child (
      runtime_key TEXT NOT NULL,
      directory TEXT NOT NULL,
      session_id TEXT NOT NULL,
      parent_id TEXT NOT NULL,
      PRIMARY KEY (runtime_key, directory, session_id)
    );
    CREATE INDEX IF NOT EXISTS session_summary_runtime_updated
      ON session_summary(runtime_key, directory, updated_at DESC, session_id DESC);
    CREATE INDEX IF NOT EXISTS session_child_parent
      ON session_child(runtime_key, directory, parent_id);
  `);
  db.prepare('INSERT OR REPLACE INTO session_index_meta(key, value) VALUES (?, ?)')
    .run('schema_version', String(SCHEMA_VERSION));

  const runtimeKey = () => runtimeKeyFor(getRuntimeConfig());
  const touchDirectory = db.prepare(`
    INSERT INTO runtime_directory(runtime_key, directory, cursor, has_more, last_synced_at, last_full_synced_at, last_accessed_at)
    VALUES (@runtimeKey, @directory, @cursor, @hasMore, @lastSyncedAt, @lastFullSyncedAt, @lastAccessedAt)
    ON CONFLICT(runtime_key, directory) DO UPDATE SET
      cursor = excluded.cursor,
      has_more = excluded.has_more,
      last_synced_at = excluded.last_synced_at,
      last_full_synced_at = CASE
        WHEN @fullSync = 1 THEN excluded.last_synced_at
        ELSE runtime_directory.last_full_synced_at
      END,
      last_accessed_at = excluded.last_accessed_at
  `);
  const touchExistingDirectory = db.prepare(`
    INSERT INTO runtime_directory(runtime_key, directory, cursor, has_more, last_synced_at, last_full_synced_at, last_accessed_at)
    VALUES (@runtimeKey, @directory, NULL, 0, 0, 0, @lastAccessedAt)
    ON CONFLICT(runtime_key, directory) DO UPDATE SET
      last_accessed_at = excluded.last_accessed_at
  `);
  const deleteDirectoryRows = db.prepare('DELETE FROM session_summary WHERE runtime_key = ? AND directory = ?');
  const existingChildrenFlags = db.prepare(`
    SELECT session_id, has_children AS hasChildren
    FROM session_summary WHERE runtime_key = ? AND directory = ?
  `);
  const insertSummary = db.prepare(`
    INSERT INTO session_summary(runtime_key, directory, session_id, title, created_at, updated_at, archived_at, parent_id, has_children)
    VALUES (@runtimeKey, @directory, @id, @title, @createdAt, @updatedAt, @archivedAt, @parentID, @hasChildren)
  `);
  const upsertSummary = db.prepare(`
    INSERT INTO session_summary(runtime_key, directory, session_id, title, created_at, updated_at, archived_at, parent_id, has_children)
    VALUES (@runtimeKey, @directory, @id, @title, @createdAt, @updatedAt, @archivedAt, @parentID, @hasChildren)
    ON CONFLICT(runtime_key, directory, session_id) DO UPDATE SET
      title = excluded.title,
      created_at = excluded.created_at,
      updated_at = excluded.updated_at,
      archived_at = excluded.archived_at,
      parent_id = excluded.parent_id,
      has_children = excluded.has_children
  `);
  const setHasChildren = db.prepare(`
    UPDATE session_summary SET has_children = ?
    WHERE runtime_key = ? AND directory = ? AND session_id = ?
  `);
  const upsertChild = db.prepare(`
    INSERT INTO session_child(runtime_key, directory, session_id, parent_id)
    VALUES (?, ?, ?, ?)
    ON CONFLICT(runtime_key, directory, session_id) DO UPDATE SET parent_id = excluded.parent_id
  `);
  const deleteChildrenForParent = db.prepare(`
    DELETE FROM session_child WHERE runtime_key = ? AND directory = ? AND parent_id = ?
  `);
  const insertChild = db.prepare(`
    INSERT INTO session_child(runtime_key, directory, session_id, parent_id) VALUES (?, ?, ?, ?)
  `);
  const parentForChild = db.prepare(`
    SELECT directory, parent_id AS parentID FROM session_child
    WHERE runtime_key = ? AND session_id = ?
  `);
  const deleteChild = db.prepare('DELETE FROM session_child WHERE runtime_key = ? AND session_id = ?');
  const deleteChildrenWithParent = db.prepare('DELETE FROM session_child WHERE runtime_key = ? AND parent_id = ?');
  const deleteOrphanChildRows = db.prepare(`
    DELETE FROM session_child
    WHERE runtime_key = ? AND directory = ?
      AND parent_id NOT IN (
        SELECT session_id FROM session_summary WHERE runtime_key = ? AND directory = ?
      )
  `);
  const countChildrenForParent = db.prepare(`
    SELECT COUNT(*) AS count FROM session_child
    WHERE runtime_key = ? AND directory = ? AND parent_id = ?
  `);

  const replaceDirectoryRows = ({ directory, sessions, cursor, hasMore, fullSync = true, now = Date.now() }) => {
    const normalizedDirectory = normalizeDirectory(directory);
    if (!normalizedDirectory) throw new Error('directory is required');
    const key = runtimeKey();
    const previousHasChildrenByID = new Map(
      existingChildrenFlags.all(key, normalizedDirectory).map((row) => [row.session_id, Boolean(row.hasChildren)]),
    );
    const summaries = Array.isArray(sessions)
      ? sessions.map((session) => toSummary(session, normalizedDirectory)).filter(Boolean).slice(0, MAX_ROOT_SESSIONS)
      : [];
    touchDirectory.run({
      runtimeKey: key,
      directory: normalizedDirectory,
      cursor: typeof cursor === 'number' && Number.isFinite(cursor) ? Math.trunc(cursor) : null,
      hasMore: toBooleanInt(hasMore),
      lastSyncedAt: toTimestamp(now),
      lastFullSyncedAt: fullSync ? toTimestamp(now) : 0,
      lastAccessedAt: toTimestamp(now),
      fullSync: toBooleanInt(fullSync),
    });
    deleteDirectoryRows.run(key, normalizedDirectory);
    for (const summary of summaries) {
      insertSummary.run({
        ...summary,
        hasChildren: toBooleanInt(summary.hasChildren ?? previousHasChildrenByID.get(summary.id) ?? false),
        runtimeKey: key,
        directory: normalizedDirectory,
      });
    }
    deleteOrphanChildRows.run(key, normalizedDirectory, key, normalizedDirectory);
  };
  const replaceDirectory = db.transaction(replaceDirectoryRows);
  const replaceDirectories = db.transaction((directories, now = Date.now()) => {
    if (!Array.isArray(directories)) throw new Error('directories must be an array');
    for (const directory of directories) {
      replaceDirectoryRows({ ...directory, now });
    }
  });

  const upsert = db.transaction((session, now = Date.now()) => {
    const summary = toSummary(session);
    if (!summary) return false;
    const key = runtimeKey();
    if (summary.archivedAt) {
      db.prepare('DELETE FROM session_summary WHERE runtime_key = ? AND session_id = ?').run(key, summary.id);
      const parent = parentForChild.get(key, summary.id);
      deleteChild.run(key, summary.id);
      if (parent) {
        setHasChildren.run(
          toBooleanInt(Number(countChildrenForParent.get(key, parent.directory, parent.parentID)?.count ?? 0) > 0),
          key,
          parent.directory,
          parent.parentID,
        );
      }
      return true;
    }
    touchExistingDirectory.run({
      runtimeKey: key,
      directory: summary.directory,
      lastAccessedAt: toTimestamp(now),
    });
    if (summary.parentID) {
      upsertChild.run(key, summary.directory, summary.id, summary.parentID);
      setHasChildren.run(1, key, summary.directory, summary.parentID);
      return true;
    }
    const existing = db.prepare(`
      SELECT has_children AS hasChildren FROM session_summary
      WHERE runtime_key = ? AND directory = ? AND session_id = ?
    `).get(key, summary.directory, summary.id);
    upsertSummary.run({
      ...summary,
      hasChildren: toBooleanInt(summary.hasChildren ?? Boolean(existing?.hasChildren)),
      runtimeKey: key,
    });
    const extra = db.prepare(`
      SELECT session_id FROM session_summary
      WHERE runtime_key = ? AND directory = ?
      ORDER BY updated_at DESC, session_id DESC
      LIMIT -1 OFFSET ?
    `).all(key, summary.directory, MAX_ROOT_SESSIONS);
    if (extra.length > 0) {
      const remove = db.prepare('DELETE FROM session_summary WHERE runtime_key = ? AND directory = ? AND session_id = ?');
      for (const row of extra) remove.run(key, summary.directory, row.session_id);
    }
    return true;
  });

  const snapshot = () => {
    const key = runtimeKey();
    const directories = db.prepare(`
      SELECT directory, cursor, has_more AS hasMore, last_synced_at AS lastSyncedAt,
        last_full_synced_at AS lastFullSyncedAt, last_accessed_at AS lastAccessedAt
      FROM runtime_directory WHERE runtime_key = ? ORDER BY last_accessed_at DESC, directory ASC
    `).all(key).map((directory) => ({
      ...directory,
      hasMore: Boolean(directory.hasMore),
      sessions: db.prepare(`
        SELECT session_id AS id, title, created_at AS createdAt, updated_at AS updatedAt,
          archived_at AS archivedAt, parent_id AS parentID, has_children AS hasChildren
        FROM session_summary WHERE runtime_key = ? AND directory = ?
        ORDER BY updated_at DESC, id DESC
      `).all(key, directory.directory).map((session) => ({
        id: session.id,
        title: session.title,
        directory: directory.directory,
        time: { created: session.createdAt, updated: session.updatedAt, ...(session.archivedAt ? { archived: session.archivedAt } : {}) },
        ...(session.parentID ? { parentID: session.parentID } : {}),
        ...(session.hasChildren ? { hasChildren: true } : {}),
      })),
    }));
    return { directories };
  };

  const remove = (sessionID) => {
    if (typeof sessionID !== 'string' || !sessionID) return false;
    const key = runtimeKey();
    const parent = parentForChild.get(key, sessionID);
    const result = db.prepare('DELETE FROM session_summary WHERE runtime_key = ? AND session_id = ?').run(key, sessionID);
    deleteChildrenWithParent.run(key, sessionID);
    deleteChild.run(key, sessionID);
    if (parent) {
      setHasChildren.run(
        toBooleanInt(Number(countChildrenForParent.get(key, parent.directory, parent.parentID)?.count ?? 0) > 0),
        key,
        parent.directory,
        parent.parentID,
      );
    }
    return result.changes > 0;
  };

  const replaceChildSessions = db.transaction((directory, parentSessionID, children) => {
    const normalizedDirectory = normalizeDirectory(directory);
    if (!normalizedDirectory || typeof parentSessionID !== 'string' || !parentSessionID) return false;
    const key = runtimeKey();
    const childIDs = Array.isArray(children)
      ? children
        .filter((child) => child && typeof child.id === 'string' && child.id)
        .map((child) => child.id)
      : [];
    deleteChildrenForParent.run(key, normalizedDirectory, parentSessionID);
    for (const childID of childIDs) insertChild.run(key, normalizedDirectory, childID, parentSessionID);
    const result = setHasChildren.run(toBooleanInt(childIDs.length > 0), key, normalizedDirectory, parentSessionID);
    return result.changes > 0;
  });

  return {
    replaceDirectory,
    replaceDirectories,
    upsert,
    remove,
    replaceChildSessions,
    snapshot,
    getRuntimeKey: runtimeKey,
    close: () => db.close(),
  };
};
