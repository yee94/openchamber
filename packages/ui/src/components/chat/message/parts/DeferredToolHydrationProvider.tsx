import React from 'react';

import { DeferredToolHydrationContext } from './deferredToolHydrationContext';

export const DeferredToolHydrationProvider: React.FC<{
    children: React.ReactNode;
    enabled: boolean;
}> = ({ children, enabled }) => (
    <DeferredToolHydrationContext.Provider value={enabled}>
        {children}
    </DeferredToolHydrationContext.Provider>
);
