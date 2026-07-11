import React from 'react';

export const MarkdownHydrationContext = React.createContext(true);

export const useMarkdownHydrationEnabled = (): boolean => {
    return React.useContext(MarkdownHydrationContext);
};
