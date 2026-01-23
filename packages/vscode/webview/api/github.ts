import type {
  GitHubAPI,
  GitHubAuthStatus,
  GitHubPullRequest,
  GitHubPullRequestCreateInput,
  GitHubPullRequestMergeInput,
  GitHubPullRequestMergeResult,
  GitHubPullRequestReadyInput,
  GitHubPullRequestReadyResult,
  GitHubPullRequestStatus,
  GitHubDeviceFlowComplete,
  GitHubDeviceFlowStart,
  GitHubUserSummary,
} from '@openchamber/ui/lib/api/types';

import { sendBridgeMessage } from './bridge';

export const createVSCodeGitHubAPI = (): GitHubAPI => ({
  authStatus: async () => sendBridgeMessage<GitHubAuthStatus>('api:github/auth:status'),
  authStart: async () => sendBridgeMessage<GitHubDeviceFlowStart>('api:github/auth:start'),
  authComplete: async (deviceCode: string) =>
    sendBridgeMessage<GitHubDeviceFlowComplete>('api:github/auth:complete', { deviceCode }),
  authDisconnect: async () => sendBridgeMessage<{ removed: boolean }>('api:github/auth:disconnect'),
  me: async () => sendBridgeMessage<GitHubUserSummary>('api:github/me'),

  prStatus: async (directory: string, branch: string) =>
    sendBridgeMessage<GitHubPullRequestStatus>('api:github/pr:status', { directory, branch }),
  prCreate: async (payload: GitHubPullRequestCreateInput) =>
    sendBridgeMessage<GitHubPullRequest>('api:github/pr:create', payload),
  prMerge: async (payload: GitHubPullRequestMergeInput) =>
    sendBridgeMessage<GitHubPullRequestMergeResult>('api:github/pr:merge', payload),
  prReady: async (payload: GitHubPullRequestReadyInput) =>
    sendBridgeMessage<GitHubPullRequestReadyResult>('api:github/pr:ready', payload),
});
