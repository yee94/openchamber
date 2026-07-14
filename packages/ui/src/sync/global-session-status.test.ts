import { beforeEach, describe, expect, test } from 'bun:test';
import type { Event } from '@opencode-ai/sdk/v2/client';
import type { Session } from '@opencode-ai/sdk/v2';

import { getSessionActivityUpdatedAt } from '@/lib/sessionActivity';
import { compareSessionsByPinnedAndTime } from '@/components/session/sidebar/utils';
import { useGlobalSessionsStore } from '@/stores/useGlobalSessionsStore';
import { applyGlobalSessionStatusEvent, useGlobalSessionStatusStore } from './global-session-status';

const statusEvent = (type: 'busy' | 'idle'): Event => ({
  type: 'session.status',
  properties: { sessionID: 'ses_1', status: { type } },
} as Event);

describe('applyGlobalSessionStatusEvent', () => {
  beforeEach(() => {
    const session = {
      id: 'ses_1',
      directory: '/repo/app',
      title: 'External session',
      time: { created: 1, updated: 10 },
    } as Session;
    useGlobalSessionsStore.setState({
      activeSessions: [session],
      archivedSessions: [],
      sessionsByDirectory: new Map([['/repo/app', [session]]]),
    });
    useGlobalSessionStatusStore.setState({ statusById: new Map() });
  });

  test('promotes activity once when a session enters busy', () => {
    const newerSession = {
      id: 'ses_2',
      directory: '/repo/app',
      title: 'Previously newer session',
      time: { created: 2, updated: 50 },
    } as Session;
    useGlobalSessionsStore.setState((state) => ({
      activeSessions: [...state.activeSessions, newerSession],
    }));

    applyGlobalSessionStatusEvent('/repo/app', statusEvent('busy'), 100);

    const first = useGlobalSessionsStore.getState().activeSessions[0];
    expect(getSessionActivityUpdatedAt(first)).toBe(100);
    expect([...useGlobalSessionsStore.getState().activeSessions]
      .sort((left, right) => compareSessionsByPinnedAndTime(left, right, new Set()))
      .map((session) => session.id)).toEqual(['ses_1', 'ses_2']);
    expect(useGlobalSessionStatusStore.getState().statusById.get('ses_1')).toEqual({
      status: 'busy',
      directory: '/repo/app',
      observedAt: 100,
    });

    applyGlobalSessionStatusEvent('/repo/app', statusEvent('busy'), 200);
    expect(getSessionActivityUpdatedAt(useGlobalSessionsStore.getState().activeSessions[0])).toBe(100);

    applyGlobalSessionStatusEvent('/repo/app', statusEvent('idle'), 250);
    applyGlobalSessionStatusEvent('/repo/app', statusEvent('busy'), 300);
    expect(getSessionActivityUpdatedAt(useGlobalSessionsStore.getState().activeSessions[0])).toBe(300);
  });
});
