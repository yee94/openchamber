import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: { fileParallelism: false },
  resolve: {
    alias: {
      'bun:test': fileURLToPath(new URL('./test/bun-test-shim.ts', import.meta.url)),
      '@': fileURLToPath(new URL('../ui/src', import.meta.url)),
    },
  },
});
