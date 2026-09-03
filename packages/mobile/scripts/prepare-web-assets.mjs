import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const mobileRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const defaultWebDist = path.resolve(mobileRoot, '../web/dist');
const defaultMobileDist = path.resolve(mobileRoot, 'dist');

export async function prepareMobileWebAssets({
  webDist = defaultWebDist,
  mobileDist = defaultMobileDist,
} = {}) {
  const webMobileHtml = path.join(webDist, 'mobile.html');
  const indexHtml = path.join(mobileDist, 'index.html');

  let html;
  try {
    html = await readFile(webMobileHtml, 'utf8');
  } catch (error) {
    throw new Error(
      `Web build has not produced ${webMobileHtml}. Finish \`bun run --cwd packages/web build\` before preparing Capacitor assets; do not copy packages/web/dist while that Vite build is still writing it.`,
      { cause: error },
    );
  }

  // Android's composer owns IME geometry through its transform FLIP. Keep the
  // native WebView viewport stable so Chromium cannot add a second layout lift.
  const nativeHtml = html.replace(
    'viewport-fit=cover"',
    'viewport-fit=cover, interactive-widget=overlays-content"',
  );

  if (nativeHtml === html) {
    throw new Error('Mobile viewport meta tag was not found while preparing native assets');
  }

  await rm(mobileDist, { recursive: true, force: true });
  await mkdir(mobileDist, { recursive: true });
  await cp(webDist, mobileDist, { recursive: true });
  await writeFile(indexHtml, nativeHtml);
}

const invokedDirectly =
  process.argv[1] !== undefined &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (invokedDirectly) {
  await prepareMobileWebAssets();
}
