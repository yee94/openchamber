import React from 'react';
import { describe, expect, mock, test } from 'bun:test';
import { renderToStaticMarkup } from 'react-dom/server';

import { I18nProvider } from '@/lib/i18n';

mock.module('@/components/ui/ModelLogo', () => ({ ModelLogo: () => null }));

const { ReadOnlyPromptBanner } = await import('./ReadOnlyPromptBanner');

describe('ReadOnlyPromptBanner', () => {
    test('capitalizes the first letter of the displayed agent name', () => {
        const markup = renderToStaticMarkup(
            <I18nProvider>
                <ReadOnlyPromptBanner agentName="fixer" />
            </I18nProvider>,
        );

        expect(markup).toContain('Agent: Fixer');
        expect(markup).toContain('>Fixer</span>');
    });
});
