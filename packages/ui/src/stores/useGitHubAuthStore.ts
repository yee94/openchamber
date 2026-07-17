import { create } from 'zustand';
import type { GitHubAuthStatus, RuntimeAPIs } from '@/lib/api/types';
import { queryClient, queryKeys } from '@/lib/queryRuntime';
import { getRuntimeTransportIdentity } from '@/lib/runtime-switch';
import {
  refreshGitHubAuthQuery,
  setGitHubAuthSnapshot,
} from '@/queries/githubAuthQueries';

type GitHubAuthStatusWithError = GitHubAuthStatus & { error?: string };

type GitHubAuthStore = {
  setStatus: (status: GitHubAuthStatusWithError | null) => void;
  refreshStatus: (
    runtimeGitHub?: RuntimeAPIs['github'],
    options?: { force?: boolean }
  ) => Promise<GitHubAuthStatusWithError | null>;
};

export const useGitHubAuthStore = create<GitHubAuthStore>(() => ({
  setStatus: (status) => setGitHubAuthSnapshot(queryClient, status),
  refreshStatus: async (runtimeGitHub, options) => {
    const transport = getRuntimeTransportIdentity();
    if (options?.force) {
      await queryClient.cancelQueries({ queryKey: queryKeys.github.auth(transport), exact: true });
    }
    return refreshGitHubAuthQuery(queryClient, runtimeGitHub, transport);
  },
}));
