import { describe, expect, test } from 'bun:test';
import { shouldSubmitCommandOnSelection } from './commandSelection';

describe('shouldSubmitCommandOnSelection', () => {
  test('submits commands selected with an immediate-submit interaction', () => {
    expect(shouldSubmitCommandOnSelection({ isSkill: false }, true)).toBe(true);
    expect(shouldSubmitCommandOnSelection({}, true)).toBe(true);
  });

  test('keeps skills and insert-only interactions in the composer', () => {
    expect(shouldSubmitCommandOnSelection({ isSkill: true }, true)).toBe(false);
    expect(shouldSubmitCommandOnSelection({ isSkill: false }, false)).toBe(false);
  });
});
