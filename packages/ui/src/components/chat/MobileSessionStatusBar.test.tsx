import React from 'react';
import { describe, expect, test } from 'bun:test';
import type { Session } from '@opencode-ai/sdk/v2';
import { renderToStaticMarkup } from 'react-dom/server';

import { I18nProvider } from '@/lib/i18n';
import { SessionItem } from './MobileSessionStatusBar';

const session = {
  id: 'ses-touch-menu',
  title: 'Touch menu session',
  time: { created: 1, updated: 1 },
  _statusType: 'idle',
} as Session & { _statusType: 'idle' };

describe('MobileSessionStatusBar SessionItem', () => {
  test('renders the session row as a touch context-menu trigger', () => {
    const markup = renderToStaticMarkup(
      <I18nProvider>
        <SessionItem
          session={session}
          isCurrent={false}
          isPinned={false}
          getSessionTitle={(value) => value.title ?? value.id}
          onClick={() => undefined}
          onTogglePinned={() => undefined}
          onShare={() => undefined}
          onCopyShareUrl={() => undefined}
          onUnshare={() => undefined}
          onArchive={() => undefined}
          needsAttention={() => false}
        />
      </I18nProvider>,
    );

    expect(markup).toContain('data-mobile-session-context-trigger="ses-touch-menu"');
    expect(markup).toContain('-webkit-touch-callout:none');
    expect(markup).toContain('Touch menu session');
  });
});
