import { describe, expect, test } from 'bun:test';
import { renderToStaticMarkup } from 'react-dom/server';

import { MarkdownRenderer, SimpleMarkdownRenderer } from './MarkdownRenderer';
import { MarkdownHydrationProvider } from './markdown/MarkdownHydrationProvider';

describe('deferred Markdown rendering', () => {
    test('renders escaped text without mounting the rich renderer', () => {
        const markup = renderToStaticMarkup(
            <MarkdownHydrationProvider enabled={false}>
                <MarkdownRenderer
                    content={'# Latest\n<script>alert("no")</script>'}
                    messageId="message-1"
                    isAnimated={false}
                />
            </MarkdownHydrationProvider>,
        );

        expect(markup).toContain('data-markdown-hydration="deferred"');
        expect(markup).toContain('&lt;script&gt;alert(&quot;no&quot;)&lt;/script&gt;');
        expect(markup).not.toContain('data-markdown-content');
    });

    test('also defers simple Markdown used by historical user and tool content', () => {
        const markup = renderToStaticMarkup(
            <MarkdownHydrationProvider enabled={false}>
                <SimpleMarkdownRenderer content="**deferred**" variant="tool" />
            </MarkdownHydrationProvider>,
        );

        expect(markup).toContain('data-markdown-hydration="deferred"');
        expect(markup).toContain('**deferred**');
    });
});
