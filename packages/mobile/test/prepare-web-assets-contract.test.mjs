import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'vitest';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');

async function source(relativePath) {
  return readFile(path.join(repoRoot, relativePath), 'utf8');
}

test('workspace build prepares Capacitor assets after the web Vite build', async () => {
  const rootPackage = await source('package.json');
  const workspaceBuild = await source('scripts/build-workspace.mjs');

  assert.match(rootPackage, /"build": "node \.\/scripts\/build-workspace\.mjs"/);
  assert.match(workspaceBuild, /packages\/web/);
  assert.match(workspaceBuild, /prepare-web-assets\.mjs/);
  assert.match(workspaceBuild, /parallelBuildPackages/);
  assert.doesNotMatch(workspaceBuild, /packages\/mobile['"`]/);
});

test('prepare-web-assets reads web mobile.html before copying into mobile/dist', async () => {
  const script = await source('packages/mobile/scripts/prepare-web-assets.mjs');

  assert.match(script, /readFile\(webMobileHtml/);
  assert.match(script, /await rm\(mobileDist/);
  assert.ok(
    script.indexOf('readFile(webMobileHtml') < script.indexOf('await rm(mobileDist'),
    'must read the web entry before wiping mobile/dist',
  );
});

test('prepareMobileWebAssets rewrites the viewport and writes index.html', async () => {
  const { prepareMobileWebAssets } = await import('../scripts/prepare-web-assets.mjs');
  const root = await mkdtemp(path.join(tmpdir(), 'oc-mobile-assets-'));
  const webDist = path.join(root, 'web');
  const mobileDist = path.join(root, 'mobile');

  try {
    await mkdir(webDist, { recursive: true });
    await writeFile(
      path.join(webDist, 'mobile.html'),
      '<meta name="viewport" content="width=device-width, viewport-fit=cover">\n',
    );
    await writeFile(path.join(webDist, 'sw.js'), '/* sw */\n');

    await prepareMobileWebAssets({ webDist, mobileDist });

    const indexHtml = await readFile(path.join(mobileDist, 'index.html'), 'utf8');
    const copiedEntry = await readFile(path.join(mobileDist, 'mobile.html'), 'utf8');
    assert.match(indexHtml, /viewport-fit=cover, interactive-widget=overlays-content/);
    assert.match(copiedEntry, /viewport-fit=cover"/);
    assert.equal(copiedEntry.includes('interactive-widget'), false);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test('prepareMobileWebAssets fails before wiping when web mobile.html is missing', async () => {
  const { prepareMobileWebAssets } = await import('../scripts/prepare-web-assets.mjs');
  const root = await mkdtemp(path.join(tmpdir(), 'oc-mobile-assets-missing-'));
  const webDist = path.join(root, 'web');
  const mobileDist = path.join(root, 'mobile');

  try {
    await mkdir(webDist, { recursive: true });
    await writeFile(path.join(webDist, 'sw.js'), '/* sw */\n');
    await mkdir(mobileDist, { recursive: true });
    await writeFile(path.join(mobileDist, 'keep.txt'), 'stale\n');

    await assert.rejects(
      () => prepareMobileWebAssets({ webDist, mobileDist }),
      /Web build has not produced/,
    );
    const kept = await readFile(path.join(mobileDist, 'keep.txt'), 'utf8');
    assert.equal(kept, 'stale\n');
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
