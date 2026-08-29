import { describe, expect, it } from 'vitest';

import { createLspStdoutParser, encodeLspFrame } from './stdio-framing.js';

describe('encodeLspFrame', () => {
  it('prefixes a JSON body with Content-Length', () => {
    const frame = encodeLspFrame('{"jsonrpc":"2.0"}');
    expect(frame.toString('utf8')).toBe('Content-Length: 17\r\n\r\n{"jsonrpc":"2.0"}');
  });
});

describe('createLspStdoutParser', () => {
  it('reassembles a message split across chunks', () => {
    const messages = [];
    const parser = createLspStdoutParser((message) => messages.push(message));
    const frame = encodeLspFrame('{"id":1}');
    parser.push(frame.subarray(0, 10));
    parser.push(frame.subarray(10));
    expect(messages).toEqual(['{"id":1}']);
  });

  it('reads two messages from one chunk', () => {
    const messages = [];
    const parser = createLspStdoutParser((message) => messages.push(message));
    parser.push(Buffer.concat([encodeLspFrame('{"a":1}'), encodeLspFrame('{"b":2}')]));
    expect(messages).toEqual(['{"a":1}', '{"b":2}']);
  });
});
