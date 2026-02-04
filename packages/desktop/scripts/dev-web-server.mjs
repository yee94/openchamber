import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const repoRoot = path.resolve(__dirname, '..', '..', '..');
const desktopDir = path.join(repoRoot, 'packages', 'desktop');
const tauriDir = path.join(desktopDir, 'src-tauri');

const inferTargetTriple = () => {
  const fromEnv = typeof process.env.TAURI_ENV_TARGET_TRIPLE === 'string' ? process.env.TAURI_ENV_TARGET_TRIPLE.trim() : '';
  if (fromEnv) return fromEnv;

  if (process.platform === 'darwin') {
    return process.arch === 'arm64' ? 'aarch64-apple-darwin' : 'x86_64-apple-darwin';
  }

  if (process.platform === 'win32') {
    return 'x86_64-pc-windows-msvc';
  }

  if (process.platform === 'linux') {
    return process.arch === 'arm64' ? 'aarch64-unknown-linux-gnu' : 'x86_64-unknown-linux-gnu';
  }

  return `${process.arch}-${process.platform}`;
};

const targetTriple = inferTargetTriple();
const sidecarName = process.platform === 'win32'
  ? `openchamber-server-${targetTriple}.exe`
  : `openchamber-server-${targetTriple}`;

const sidecarPath = path.join(tauriDir, 'sidecars', sidecarName);
const distDir = path.join(tauriDir, 'resources', 'web-dist');

const run = (cmd, args, cwd) => {
  const result = spawnSync(cmd, args, { cwd, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`Command failed: ${cmd} ${args.join(' ')}`);
  }
};

console.log('[desktop] ensuring sidecar + web-dist...');
run('node', ['./scripts/build-sidecar.mjs'], desktopDir);

console.log('[desktop] starting dev server on http://127.0.0.1:3001 ...');

const child = spawn(sidecarPath, ['--port', '3001'], {
  cwd: repoRoot,
  stdio: 'inherit',
  env: {
    ...process.env,
    OPENCHAMBER_HOST: '127.0.0.1',
    OPENCHAMBER_DIST_DIR: distDir,
    NO_PROXY: process.env.NO_PROXY || 'localhost,127.0.0.1',
    no_proxy: process.env.no_proxy || 'localhost,127.0.0.1',
  },
});

const shutdown = () => {
  try {
    child.kill('SIGTERM');
  } catch {
    // ignore
  }
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
process.on('exit', shutdown);
