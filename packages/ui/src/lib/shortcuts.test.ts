import { describe, expect, test } from 'bun:test';

import { getEffectiveShortcutCombo, getEffectiveShortcutCombos } from './shortcuts';

describe('getEffectiveShortcutCombo', () => {
  test('uses Ctrl+backtick as the default terminal shortcut', () => {
    expect(getEffectiveShortcutCombo('toggle_terminal')).toBe('ctrl+backtick');
  });
});

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
