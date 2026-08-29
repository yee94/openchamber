import { EventEmitter } from 'node:events';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { createLspProcessManager } from './process-manager.js';

const makeChild = () => {
  const child = new EventEmitter();
  child.stdin = { writable: true, write: vi.fn() };
  child.stdout = new EventEmitter();
  child.stdout.setEncoding = vi.fn();
  child.stderr = new EventEmitter();
  child.stderr.setEncoding = vi.fn();
  child.kill = vi.fn();
  return child;
};

describe('createLspProcessManager', () => {
  const tempDirs = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    tempDirs.length = 0;
  });

  const makeWorkspace = () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'oc-lsp-'));
    tempDirs.push(dir);
    return dir;
  };

  it('rejects a missing directory', () => {
    const manager = createLspProcessManager({
      spawn: vi.fn(),
      resolveServer: () => '/bin/false',
      resolveTsserver: () => '/bin/false',
    });
    expect(() => manager.acquire('/definitely-missing-oc-lsp')).toThrow('directory does not exist');
  });

  it('reuses one child for the same directory and writes framed JSON', () => {
    const workspace = makeWorkspace();
    const child = makeChild();
    const spawn = vi.fn(() => child);
    const encodeFrame = vi.fn((body) => Buffer.from(body));
    const manager = createLspProcessManager({
      spawn,
      resolveServer: () => '/tmp/tls.js',
      resolveTsserver: () => '/tmp/tsserver.js',
      encodeFrame,
    });

    const first = manager.acquire(workspace);
    const second = manager.acquire(workspace);
    expect(spawn).toHaveBeenCalledTimes(1);
    expect(manager.size()).toBe(1);

    first.send('{"id":1}');
    expect(encodeFrame).toHaveBeenCalledWith('{"id":1}');
    expect(child.stdin.write).toHaveBeenCalled();

    first.release();
    second.release();
    manager.stop();
  });

  it('forwards parsed stdout to every subscriber', () => {
    const workspace = makeWorkspace();
    const child = makeChild();
    const manager = createLspProcessManager({
      spawn: () => child,
      resolveServer: () => '/tmp/tls.js',
      resolveTsserver: () => '/tmp/tsserver.js',
      createParser: (onMessage) => ({
        push: (chunk) => onMessage(String(chunk)),
      }),
    });

    const handle = manager.acquire(workspace);
    const received = [];
    const unsubscribe = handle.subscribe((message) => received.push(message));
    child.stdout.emit('data', '{"result":true}');
    expect(received).toEqual(['{"result":true}']);
    unsubscribe();
    handle.release();
    manager.stop();
  });
});
