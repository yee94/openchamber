import { describe, expect, test } from 'bun:test';

import { MobileWindowStack } from './MobileWindowStack';

describe('MobileWindowStack', () => {
  test('locks the body until the final window leaves', () => {
    const stack = new MobileWindowStack();
    const body = { style: { overflow: 'scroll' } };
    const first = stack.add({ id: 'first', onClose: () => {} }, body);
    const second = stack.add({ id: 'second', onClose: () => {} }, body);
    expect(body.style.overflow).toBe('hidden');
    second();
    expect(body.style.overflow).toBe('hidden');
    first();
    expect(body.style.overflow).toBe('scroll');
  });

  test('closes only the top window', () => {
    const stack = new MobileWindowStack();
    const closed: string[] = [];
    stack.add({ id: 'first', onClose: () => closed.push('first') });
    stack.add({ id: 'second', onClose: () => closed.push('second') });
    stack.closeTop();
    expect(closed).toEqual(['second']);
  });
});
