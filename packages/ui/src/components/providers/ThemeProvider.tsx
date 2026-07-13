import React from 'react';
import { useUIStore } from '@/stores/useUIStore';

interface ThemeProviderProps {
  children: React.ReactNode;
}

export const ThemeProvider: React.FC<ThemeProviderProps> = ({ children }) => {
  const fontSize = useUIStore((state) => state.fontSize);
  const codeFontSize = useUIStore((state) => state.codeFontSize);
  const applyTypography = useUIStore((state) => state.applyTypography);
  const padding = useUIStore((state) => state.padding);
  const applyPadding = useUIStore((state) => state.applyPadding);

  React.useLayoutEffect(() => {
    applyTypography();
    applyPadding();
  }, [fontSize, codeFontSize, applyTypography, padding, applyPadding]);

  return <>{children}</>;
};
