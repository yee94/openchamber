import React from 'react';

export const DeferredToolHydrationContext = React.createContext(false);

export const useDeferredToolHydration = (): boolean => (
    React.useContext(DeferredToolHydrationContext)
);
