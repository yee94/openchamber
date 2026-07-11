import React from 'react';

import { MarkdownHydrationContext } from './markdownHydrationContext';

export const MarkdownHydrationProvider: React.FC<{
    children: React.ReactNode;
    enabled: boolean;
}> = ({ children, enabled }) => (
    <MarkdownHydrationContext.Provider value={enabled}>
        {children}
    </MarkdownHydrationContext.Provider>
);
