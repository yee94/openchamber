import { spawn as defaultSpawn } from 'node:child_process';
import fs from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';

import { createLspStdoutParser, encodeLspFrame } from './stdio-framing.js';

const require = createRequire(import.meta.url);

const DEFAULT_IDLE_MS = 10 * 60 * 1000;
const DEFAULT_MAX_PROCESSES = 4;

const resolvePackageBin = (packageName, binName) => {
  const packageJsonPath = require.resolve(`${packageName}/package.json`);
  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
  const binField = packageJson.bin;
  const relativeBin = typeof binField === 'string'
    ? binField
    : binField?.[binName];
  if (!relativeBin) {
    throw new Error(`Missing bin "${binName}" in ${packageName}`);
  }
  return path.resolve(path.dirname(packageJsonPath), relativeBin);
};

const resolveTypescriptLanguageServer = () => (
  resolvePackageBin('typescript-language-server', 'typescript-language-server')
);

const resolveTypescriptTsserver = () => require.resolve('typescript/lib/tsserver.js');

const assertWorkspaceDirectory = (directory) => {
  if (typeof directory !== 'string' || directory.trim().length === 0) {
    throw new Error('directory is required');
  }
  const resolved = path.resolve(directory);
  let stat;
  try {
    stat = fs.statSync(resolved);
  } catch {
    throw new Error('directory does not exist');
  }
  if (!stat.isDirectory()) {
    throw new Error('path is not a directory');
  }
  return resolved;
};

export const createLspProcessManager = (options = {}) => {
  const spawnChild = options.spawn ?? defaultSpawn;
  const resolveServer = options.resolveServer ?? resolveTypescriptLanguageServer;
  const resolveTsserver = options.resolveTsserver ?? resolveTypescriptTsserver;
  const idleMs = options.idleMs ?? DEFAULT_IDLE_MS;
  const maxProcesses = options.maxProcesses ?? DEFAULT_MAX_PROCESSES;
  const sessions = new Map();

  const disposeSession = (session, signal = 'SIGTERM') => {
    if (session.idleTimer) {
      clearTimeout(session.idleTimer);
      session.idleTimer = null;
    }
    session.subscribers.clear();
    try {
      session.child.kill(signal);
    } catch {
      // already gone
    }
    sessions.delete(session.directory);
  };

  const evictIfNeeded = () => {
    if (sessions.size < maxProcesses) {
      return;
    }
    const unused = [...sessions.values()]
      .filter((session) => session.subscribers.size === 0)
      .sort((left, right) => left.lastUsedAt - right.lastUsedAt);
    const victim = unused[0];
    if (victim) {
      disposeSession(victim);
    }
  };

  const startSession = (directory) => {
    evictIfNeeded();
    const serverPath = resolveServer();
    const args = [serverPath, '--stdio'];
    try {
      args.push('--tsserver-path', resolveTsserver());
    } catch {
      // Workspace TypeScript is enough when our packaged copy is missing.
    }

    const child = spawnChild(process.execPath, args, {
      cwd: directory,
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env },
    });

    const session = {
      directory,
      child,
      subscribers: new Set(),
      lastUsedAt: Date.now(),
      idleTimer: null,
    };

    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');

    const parseStdout = options.createParser ?? createLspStdoutParser;
    const parser = parseStdout((message) => {
      session.lastUsedAt = Date.now();
      for (const subscriber of session.subscribers) {
        subscriber(message);
      }
    });

    child.stdout.on('data', (chunk) => {
      parser.push(chunk);
    });

    child.on('exit', () => {
      if (sessions.get(directory) === session) {
        sessions.delete(directory);
      }
    });

    sessions.set(directory, session);
    return session;
  };

  const clearIdle = (session) => {
    if (session.idleTimer) {
      clearTimeout(session.idleTimer);
      session.idleTimer = null;
    }
  };

  const scheduleIdle = (session) => {
    clearIdle(session);
    if (session.subscribers.size > 0) {
      return;
    }
    session.idleTimer = setTimeout(() => {
      if (session.subscribers.size === 0) {
        disposeSession(session);
      }
    }, idleMs);
  };

  const acquire = (directory) => {
    const resolved = assertWorkspaceDirectory(directory);
    const session = sessions.get(resolved) ?? startSession(resolved);
    session.lastUsedAt = Date.now();
    clearIdle(session);

    const subscribers = new Set();
    const send = (jsonBody) => {
      if (!session.child.stdin.writable) {
        throw new Error('language server stdin is closed');
      }
      const encode = options.encodeFrame ?? encodeLspFrame;
      session.child.stdin.write(encode(jsonBody));
      session.lastUsedAt = Date.now();
    };

    const subscribe = (handler) => {
      subscribers.add(handler);
      session.subscribers.add(handler);
      return () => {
        subscribers.delete(handler);
        session.subscribers.delete(handler);
      };
    };

    const release = () => {
      for (const handler of subscribers) {
        session.subscribers.delete(handler);
      }
      subscribers.clear();
      scheduleIdle(session);
    };

    return { directory: resolved, send, subscribe, release };
  };

  const stop = () => {
    for (const session of [...sessions.values()]) {
      disposeSession(session, 'SIGKILL');
    }
  };

  return { acquire, stop, size: () => sessions.size };
};
