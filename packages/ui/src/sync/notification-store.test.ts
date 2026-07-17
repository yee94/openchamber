import { beforeEach, describe, expect, test } from 'bun:test';
import { useNotificationStore } from './notification-store';

describe('notification store', () => {
  beforeEach(() => {
    useNotificationStore.setState({
      list: [],
      index: {
        session: { unseenCount: {}, unseenHasError: {} },
        project: { unseenCount: {}, unseenHasError: {} },
      },
    });
  });

  test('clears a completed session marker when the session is viewed', () => {
    const store = useNotificationStore.getState();
    store.append({
      directory: '/project',
      session: 'root-session',
      time: Date.now(),
      viewed: false,
      type: 'turn-complete',
    });

    expect(useNotificationStore.getState().sessionUnseenCount('root-session')).toBe(1);

    useNotificationStore.getState().markSessionViewed('root-session');

    expect(useNotificationStore.getState().sessionUnseenCount('root-session')).toBe(0);
  });
});
