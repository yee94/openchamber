import { describe, expect, test } from 'bun:test';

import { createUuid } from './uuid';

describe('createUuid', () => {
  test('uses native randomUUID when available', () => {
    expect(createUuid({ randomUUID: () => 'native-uuid' })).toBe('native-uuid');
  });

  test('creates a UUID v4 with getRandomValues', () => {
    const uuid = createUuid({
      getRandomValues: (bytes) => {
        bytes.fill(0);
        return bytes;
      },
    });

    expect(uuid).toBe('00000000-0000-4000-8000-000000000000');
  });

  test('creates a UUID v4 when WebView crypto APIs are unavailable', () => {
    const uuidV4Pattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
    expect(uuidV4Pattern.test(createUuid(null))).toBe(true);
  });
});
