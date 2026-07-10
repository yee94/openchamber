import { describe, expect, test } from 'bun:test';

import { buildDeepLink, parseDeepLink } from './deepLinks';

describe('parseDeepLink (OpenCode-aligned)', () => {
  test('parses new-session with directory query like OpenCode', () => {
    expect(parseDeepLink('openchamber://new-session?directory=/tmp/demo')).toEqual({
      type: 'new-session',
      directory: '/tmp/demo',
      projectId: undefined,
      agent: undefined,
      model: undefined,
      prompt: undefined,
    });
  });

  test('parses new-session with optional prompt', () => {
    expect(parseDeepLink('openchamber://new-session?directory=/tmp/demo&prompt=hello%20world')).toEqual({
      type: 'new-session',
      directory: '/tmp/demo',
      projectId: undefined,
      agent: undefined,
      model: undefined,
      prompt: 'hello world',
    });
  });

  test('accepts legacy dir= and CodeX-style path= aliases', () => {
    const legacy = parseDeepLink('openchamber://new-session?dir=/legacy');
    expect(legacy?.type === 'new-session' ? legacy.directory : undefined).toBe('/legacy');
    const codexStyle = parseDeepLink('openchamber://new-session?path=/codex');
    expect(codexStyle?.type === 'new-session' ? codexStyle.directory : undefined).toBe('/codex');
  });

  test('parses open-project?directory= like OpenCode', () => {
    expect(parseDeepLink('openchamber://open-project?directory=/tmp/demo')).toEqual({
      type: 'open-project',
      directory: '/tmp/demo',
    });
  });

  test('parses legacy project/<path> form', () => {
    expect(parseDeepLink('openchamber://project/%2Ftmp%2Fdemo')).toEqual({
      type: 'open-project',
      directory: '/tmp/demo',
    });
  });

  test('ignores open-project without a directory', () => {
    expect(parseDeepLink('openchamber://open-project')).toBeNull();
    expect(parseDeepLink('openchamber://open-project?directory=')).toBeNull();
  });
});

describe('buildDeepLink (OpenCode-aligned)', () => {
  test('emits new-session?directory= for external openers', () => {
    expect(buildDeepLink({ type: 'new-session', directory: '/tmp/demo', prompt: 'ship it' })).toBe(
      'openchamber://new-session?directory=%2Ftmp%2Fdemo&prompt=ship+it',
    );
  });

  test('emits open-project?directory=', () => {
    expect(buildDeepLink({ type: 'open-project', directory: '/tmp/demo' })).toBe(
      'openchamber://open-project?directory=%2Ftmp%2Fdemo',
    );
  });
});
