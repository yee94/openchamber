import React from 'react';
import { describe, expect, test } from 'bun:test';
import { renderToStaticMarkup } from 'react-dom/server';

import { I18nProvider } from '@/lib/i18n';
import type { GitRemote } from '@/lib/gitApi';
import { SyncActions } from './SyncActions';

const remote: GitRemote = {
  name: 'origin',
  fetchUrl: 'https://example.com/repository.git',
  pushUrl: 'https://example.com/repository.git',
};

function renderSyncActions(aheadCount: number, behindCount: number) {
  return renderToStaticMarkup(
    <I18nProvider>
      <SyncActions
        syncAction={null}
        remotes={[remote]}
        onSync={() => undefined}
        disabled={false}
        aheadCount={aheadCount}
        behindCount={behindCount}
        trackingRemoteName="origin"
      />
    </I18nProvider>,
  );
}

describe('SyncActions', () => {
  test('shows the total number of commits that need syncing', () => {
    const markup = renderSyncActions(2, 3);

    expect(/<span[^>]*aria-hidden="true"[^>]*>5<\/span>/.test(markup)).toBe(true);
  });

  test('keeps the icon-only layout when the branch is synchronized', () => {
    const markup = renderSyncActions(0, 0);

    expect(/<span[^>]*aria-hidden="true"[^>]*>\d+<\/span>/.test(markup)).toBe(false);
  });
});
