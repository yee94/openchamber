#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const webRoot = path.join(repoRoot, 'packages', 'web');
const npmCommand = process.platform === 'win32' ? 'npm.cmd' : 'npm';
const forceRebuild = process.argv.includes('--force');

function probeBinding() {
  return spawnSync(process.execPath, [
    '-e',
    "const Database = require('better-sqlite3'); const db = new Database(':memory:'); db.exec('SELECT 1'); db.close();",
  ], {
    cwd: webRoot,
    encoding: 'utf8',
  });
}

function fail(message, result) {
  const details = result?.stderr?.trim() || result?.error?.message || '';
  throw new Error(details ? `${message}\n${details}` : message);
}

let probe = probeBinding();
if (forceRebuild || probe.status !== 0) {
  console.log(`[dev:native] rebuilding better-sqlite3 for Node ${process.version} (ABI ${process.versions.modules})...`);
  const rebuild = spawnSync(npmCommand, ['rebuild', 'better-sqlite3', '--foreground-scripts'], {
    cwd: repoRoot,
    stdio: 'inherit',
  });
  if (rebuild.status !== 0) {
    fail('[dev:native] better-sqlite3 rebuild failed.', rebuild);
  }
  probe = probeBinding();
}

if (probe.status !== 0) {
  fail('[dev:native] better-sqlite3 could not load in the Node runtime.', probe);
}

console.log(`[dev:native] better-sqlite3 is ready for Node ABI ${process.versions.modules}.`);
