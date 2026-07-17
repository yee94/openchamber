import { QueryClientProvider } from '@tanstack/react-query';
import { useEffect, type ReactNode } from 'react';
import { installQueryRuntimeLifecycle, queryClient } from './queryRuntime';

export function QueryRuntimeProvider({ children }: { children: ReactNode }) {
  useEffect(() => installQueryRuntimeLifecycle(queryClient), []);

  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}
