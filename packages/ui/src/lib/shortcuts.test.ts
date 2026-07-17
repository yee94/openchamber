import { describe, expect, test } from 'bun:test';

import { getEffectiveShortcutCombos } from './shortcuts';

describe('getEffectiveShortcutCombos', () => {
  test('returns the default session navigation shortcut and its alias', () => {
    expect(getEffectiveShortcutCombos('previous_session')).toEqual(['mod+shift+[', 'mod+arrowup']);
    expect(getEffectiveShortcutCombos('next_session')).toEqual(['mod+shift+]', 'mod+arrowdown']);
  });

  test('uses only the configured shortcut when an action is customized', () => {
    expect(getEffectiveShortcutCombos('previous_session', {
      previous_session: 'mod+shift+arrowup',
    })).toEqual(['mod+shift+arrowup']);
  });
});
