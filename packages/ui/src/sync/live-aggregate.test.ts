import { describe, expect, test } from 'bun:test';
import type { SessionStatus } from '@opencode-ai/sdk/v2/client';
import type { Session } from '@opencode-ai/sdk/v2';

import { findLiveSessionStatusSnapshot } from './live-aggregate';
import type { State } from './types';

describe('findLiveSessionStatus', () => {
  test('uses the latest status observation across duplicate directory stores', () => {
    const olderSessionWithNewerBusy = {
      session: [{ id: 'ses_1', time: { created: 1, updated: 10 } } as Session],
      session_status: { ses_1: { type: 'busy' } as SessionStatus },
      session_status_observed_at: { ses_1: 200 },
    } as Pick<State, 'session' | 'session_status' | 'session_status_observed_at'>;
    const newerSessionWithOlderIdle = {
      session: [{ id: 'ses_1', time: { created: 1, updated: 20 } } as Session],
      session_status: { ses_1: { type: 'idle' } as SessionStatus },
      session_status_observed_at: { ses_1: 100 },
    } as Pick<State, 'session' | 'session_status' | 'session_status_observed_at'>;

    expect(findLiveSessionStatusSnapshot([
      newerSessionWithOlderIdle,
      olderSessionWithNewerBusy,
    ], 'ses_1')).toEqual({ status: { type: 'busy' }, observedAt: 200 });
  });
});
