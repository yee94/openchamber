import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

// `@openchamber/mobile` copies `packages/web/dist` (including `mobile.html`).
// Vite `emptyOutDir` plus that copy cannot share the directory with a second
// in-flight `vite build` — PR checks `bun run --filter '*' build` raced and
// dropped `mobile.html` after the mobile Vite process reported it.
const parallelBuildPackages = [
  'packages/ui',
  'packages/web',
  'packages/vscode',
  'packages/electron',
];

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: 'inherit', cwd: root });
    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${command} ${args.join(' ')} exited ${code}`));
    });
  });
}

const settled = await Promise.allSettled(
  parallelBuildPackages.map((cwd) => run('bun', ['run', '--cwd', cwd, 'build'])),
);
const failures = settled.filter((result) => result.status === 'rejected');
if (failures.length > 0) {
  for (const failure of failures) {
    console.error(failure.reason);
  }
  process.exit(1);
}

await run('node', ['packages/mobile/scripts/prepare-web-assets.mjs']);
