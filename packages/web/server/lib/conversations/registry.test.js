import { describe, expect, it, vi } from 'vitest';
import { fingerprint, createOperationRegistry } from './registry.js';

describe('fingerprint', () => {
  it('produces same output for identical sanitized input', () => {
    const a = { directory: '/a', messageID: 'm1', model: { providerID: 'o', modelID: 'g' }, parts: [{ type: 'text', text: 'hi' }] };
    const b = { directory: '/a', messageID: 'm1', model: { providerID: 'o', modelID: 'g' }, parts: [{ type: 'text', text: 'hi' }] };
    expect(fingerprint(a)).toBe(fingerprint(b));
  });

  it('differs when any field changes', () => {
    const a = { directory: '/a', messageID: 'm1', model: { providerID: 'o', modelID: 'g' }, parts: [{ type: 'text', text: 'hi' }] };
    const b = { directory: '/b', messageID: 'm1', model: { providerID: 'o', modelID: 'g' }, parts: [{ type: 'text', text: 'hi' }] };
    expect(fingerprint(a)).not.toBe(fingerprint(b));
  });

  it('differs when part text changes', () => {
    const a = { parts: [{ type: 'text', text: 'hi' }] };
    const b = { parts: [{ type: 'text', text: 'bye' }] };
    expect(fingerprint(a)).not.toBe(fingerprint(b));
  });

  it('stable across key ordering', () => {
    const a = { directory: '/a', messageID: 'm1' };
    const b = { messageID: 'm1', directory: '/a' };
    expect(fingerprint(a)).toBe(fingerprint(b));
  });

  it('stable for nested objects', () => {
    const a = { model: { providerID: 'o', modelID: 'g' }, title: 'T' };
    const b = { title: 'T', model: { modelID: 'g', providerID: 'o' } };
    expect(fingerprint(a)).toBe(fingerprint(b));
  });

  it('null and undefined treated the same', () => {
    const a = { a: null, b: 1 };
    const b = { b: 1 };
    expect(fingerprint(a)).toBe(fingerprint(b));
  });

  it('parts order matters', () => {
    const a = { parts: [{ type: 'text', text: 'A' }, { type: 'text', text: 'B' }] };
    const b = { parts: [{ type: 'text', text: 'B' }, { type: 'text', text: 'A' }] };
    expect(fingerprint(a)).not.toBe(fingerprint(b));
  });
});

describe('operation registry', () => {
  it('runs factory and returns result', async () => {
    const r = createOperationRegistry();
    const { status, result } = await r.run('k1', 'fp1', async () => ({ ok: true }));
    expect(status).toBe('ran');
    expect(result.ok).toBe(true);
  });

  it('deduplicates concurrent same key+fp by returning same promise', async () => {
    const r = createOperationRegistry();
    let calls = 0;
    const factory = async () => { calls += 1; return { ok: true }; };

    const [a, b] = await Promise.all([
      r.run('k1', 'fp1', factory),
      r.run('k1', 'fp1', factory),
    ]);

    expect(calls).toBe(1);
    expect(a.status).toBe('ran');
    expect(b.status).toBe('dedup');
    expect(a.result.ok).toBe(true);
    expect(b.result.ok).toBe(true);
  });

  it('returns conflict for same key with different fingerprint', async () => {
    const r = createOperationRegistry();

    // First inflight
    const p1 = r.run('k1', 'fp1', async () => {
      await new Promise((r) => setTimeout(r, 100));
      return { ok: true };
    });

    // Concurrent with different fingerprint
    const p2 = await r.run('k1', 'fp2', async () => ({ ok: true }));
    expect(p2.status).toBe('conflict');

    await p1;
  });

  it('caches completed result and returns dedup on re-request', async () => {
    const r = createOperationRegistry();
    let calls = 0;
    const factory = async () => { calls += 1; return { ok: true, phase: 'prompt' }; };

    // First run
    const a = await r.run('k1', 'fp1', factory);
    expect(a.status).toBe('ran');
    expect(calls).toBe(1);

    // Second — should be from cache
    const b = await r.run('k1', 'fp1', factory);
    expect(b.status).toBe('dedup');
    expect(calls).toBe(1);
    expect(b.result.ok).toBe(true);
  });

  it('returns conflict for completed key with different fingerprint', async () => {
    const r = createOperationRegistry();
    await r.run('k1', 'fp1', async () => ({ ok: true }));
    const p2 = await r.run('k1', 'fp2', async () => ({ ok: true }));
    expect(p2.status).toBe('conflict');
  });

  it('expires completed entries after TTL', async () => {
    let now = 0;
    const clock = { now: () => now };
    const r = createOperationRegistry({ ttlMs: 100, clock, maxEntries: 10 });

    let calls = 0;
    const factory = async () => { calls += 1; return { ok: true }; };

    // Run and complete
    now = 1000;
    await r.run('k1', 'fp1', factory);
    expect(calls).toBe(1);
    // Re-request immediately -> cached
    await r.run('k1', 'fp1', factory);
    expect(calls).toBe(1);

    // Advance past TTL
    now = 1200;
    await r.run('k1', 'fp1', factory);
    expect(calls).toBe(2); // factory called again
  });

  it('evicts oldest completed when at capacity and factory runs', async () => {
    let now = 0;
    const clock = { now: () => now };
    const r = createOperationRegistry({ ttlMs: 3600000, clock, maxEntries: 3 });

    // Fill with completed entries
    now = 1000;
    await r.run('k0', 'fp0', async () => ({ ok: true }));
    now = 1010;
    await r.run('k1', 'fp1', async () => ({ ok: true }));
    now = 1020;
    await r.run('k2', 'fp2', async () => ({ ok: true }));

    const snap = r.snapshot();
    expect(snap.total).toBe(3);

    // New key should evict oldest (k0 at 1000)
    now = 2000;
    const result = await r.run('k3', 'fp3', async () => ({ ok: true }));
    expect(result.status).toBe('ran');

    // k1 should still be cached
    const dedup = await r.run('k1', 'fp1', async () => ({ ok: true }));
    expect(dedup.status).toBe('dedup');

    const snap2 = r.snapshot();
    expect(snap2.total).toBe(3);
  });

  it('returns unavailable when all entries are inflight', async () => {
    let resolve;
    const block = new Promise((r) => { resolve = r; });
    const r = createOperationRegistry({ maxEntries: 2 });

    // Two inflight
    const p1 = r.run('k1', 'fp1', async () => { await block; return { ok: true }; });
    const p2 = r.run('k2', 'fp2', async () => { await block; return { ok: true }; });

    // Third should get unavailable
    const p3 = await r.run('k3', 'fp3', async () => ({ ok: true }));
    expect(p3.status).toBe('unavailable');

    resolve();
    await Promise.all([p1, p2]);
  });

  it('invalidates entry and returns internal on unexpected factory throw', async () => {
    const r = createOperationRegistry();

    const result = await r.run('k1', 'fp1', async () => {
      throw new Error('boom');
    });

    expect(result.status).toBe('ran');
    expect(result.result.ok).toBe(false);
    expect(result.result.phase).toBe('internal');

    // k1 should NOT be in registry anymore — retry is allowed
    const snap = r.snapshot();
    expect(snap.total).toBe(0);

    // Retry with same key should re-run
    const retry = await r.run('k1', 'fp1', async () => ({ ok: true }));
    expect(retry.status).toBe('ran');
    expect(retry.result.ok).toBe(true);
  });

  it('snapshot reports correct counts', async () => {
    const r = createOperationRegistry();

    expect(r.snapshot()).toEqual({ total: 0, inflight: 0, completed: 0 });

    let resolve;
    const block = new Promise((r) => { resolve = r; });
    const p1 = r.run('k1', 'fp1', async () => { await block; return { ok: true }; });

    let snap = r.snapshot();
    expect(snap.inflight).toBe(1);

    resolve();
    await p1;

    snap = r.snapshot();
    expect(snap.completed).toBe(1);
    expect(snap.inflight).toBe(0);
  });
});
