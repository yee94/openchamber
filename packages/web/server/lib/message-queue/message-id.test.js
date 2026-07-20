import { describe, expect, it } from 'vitest';
import { createAscendingMessageID } from './message-id.js';

const MESSAGE_ID = /^msg_[0-9a-f]{12}[0-9A-Za-z]{14}$/;

describe('createAscendingMessageID', () => {
  it('creates the OpenCode ascending message ID format', () => {
    expect(createAscendingMessageID(undefined, () => 1_000)).toMatch(MESSAGE_ID);
  });

  it('sorts strictly after a valid OpenCode floor ID', () => {
    const floor = 'msg_f7ecb07bf001adqJK0ArtG123K';
    expect(createAscendingMessageID(floor, () => 0) > floor).toBe(true);
  });

  it('increments across calls with the same clock value', () => {
    const first = createAscendingMessageID(undefined, () => 2_000);
    const second = createAscendingMessageID(undefined, () => 2_000);
    expect(second > first).toBe(true);
  });

  it('ignores malformed floor IDs safely', () => {
    expect(() => createAscendingMessageID('msg_zzzzzzzzzzzzinvalid', () => 3_000)).not.toThrow();
    expect(createAscendingMessageID('msg_123', () => 3_000)).toMatch(MESSAGE_ID);
  });
});
