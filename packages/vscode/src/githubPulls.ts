import { resolveRepoFromDirectory } from './githubPr';

const API_BASE = 'https://api.github.com';

type JsonRecord = Record<string, unknown>;

type GitHubRepoRef = { owner: string; repo: string; url: string };

type GitHubUserSummary = { login: string; id?: number; avatarUrl?: string; name?: string; email?: string };

type GitHubChecksSummary = {
  state: 'success' | 'failure' | 'pending' | 'unknown';
  total: number;
  success: number;
  failure: number;
  pending: number;
};

type GitHubPullRequestHeadRepo = { owner: string; repo: string; url: string; cloneUrl?: string };

type GitHubPullRequestSummary = {
  number: number;
  title: string;
  url: string;
  state: 'open' | 'closed' | 'merged';
  draft: boolean;
  base: string;
  head: string;
  headSha?: string;
  mergeable?: boolean | null;
  mergeableState?: string | null;
  author?: GitHubUserSummary | null;
  body?: string;
  createdAt?: string;
  updatedAt?: string;
  headLabel?: string;
  headRepo?: GitHubPullRequestHeadRepo | null;
};

type GitHubIssueComment = {
  id: number;
  url: string;
  body: string;
  author?: GitHubUserSummary | null;
  createdAt?: string;
  updatedAt?: string;
};

type GitHubPullRequestReviewComment = {
  id: number;
  url: string;
  body: string;
  author?: GitHubUserSummary | null;
  path?: string;
  line?: number | null;
  position?: number | null;
  createdAt?: string;
  updatedAt?: string;
};

type GitHubPullRequestFile = {
  filename: string;
  status?: string;
  additions?: number;
  deletions?: number;
  changes?: number;
  patch?: string;
};

export type GitHubPullRequestsListResult = {
  connected: boolean;
  repo?: GitHubRepoRef | null;
  prs?: GitHubPullRequestSummary[];
  page?: number;
  hasMore?: boolean;
};

export type GitHubPullRequestContextResult = {
  connected: boolean;
  repo?: GitHubRepoRef | null;
  pr?: GitHubPullRequestSummary | null;
  issueComments?: GitHubIssueComment[];
  reviewComments?: GitHubPullRequestReviewComment[];
  files?: GitHubPullRequestFile[];
  diff?: string;
  checks?: GitHubChecksSummary | null;
};

const githubFetch = async (
  url: string,
  accessToken: string,
  init?: RequestInit,
): Promise<Response> => {
  return fetch(url, {
    ...init,
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${accessToken}`,
      'User-Agent': 'OpenChamber',
      ...(init?.headers || {}),
    },
  });
};

const githubFetchText = async (
  url: string,
  accessToken: string,
  accept: string,
): Promise<Response> => {
  return fetch(url, {
    headers: {
      Accept: accept,
      Authorization: `Bearer ${accessToken}`,
      'User-Agent': 'OpenChamber',
    },
  });
};

const jsonOrNull = async <T>(response: Response): Promise<T | null> => {
  return (await response.json().catch(() => null)) as T | null;
};

const readString = (value: unknown): string => (typeof value === 'string' ? value : '');

const mapUser = (raw: unknown): GitHubUserSummary | null => {
  const rec = raw && typeof raw === 'object' ? (raw as JsonRecord) : null;
  const login = readString(rec?.login);
  if (!login) return null;
  return {
    login,
    id: typeof rec?.id === 'number' ? rec.id : undefined,
    avatarUrl: readString(rec?.avatar_url) || undefined,
    name: undefined,
    email: undefined,
  };
};

const mapHeadRepo = (raw: unknown): GitHubPullRequestHeadRepo | null => {
  const rec = raw && typeof raw === 'object' ? (raw as JsonRecord) : null;
  const ownerLogin = readString((rec?.owner as JsonRecord | undefined)?.login);
  const repo = readString(rec?.name);
  const url = readString(rec?.html_url);
  if (!ownerLogin || !repo || !url) return null;
  return {
    owner: ownerLogin,
    repo,
    url,
    cloneUrl: readString(rec?.clone_url) || undefined,
  };
};

const computeChecks = async (accessToken: string, repo: GitHubRepoRef, sha: string): Promise<GitHubChecksSummary | null> => {
  const runsResp = await githubFetch(`${API_BASE}/repos/${repo.owner}/${repo.repo}/commits/${sha}/check-runs`, accessToken);
  const runsJson = await jsonOrNull<JsonRecord>(runsResp);
  const runs = Array.isArray((runsJson as JsonRecord | null)?.check_runs)
    ? ((runsJson as JsonRecord).check_runs as unknown[])
    : [];

  if (runsResp.ok && runs.length > 0) {
    const counts = { success: 0, failure: 0, pending: 0 };
    runs.forEach((r) => {
      const rec = (r && typeof r === 'object') ? (r as JsonRecord) : null;
      const status = readString(rec?.status);
      const conclusion = readString(rec?.conclusion);
      if (status === 'queued' || status === 'in_progress') {
        counts.pending += 1;
        return;
      }
      if (!conclusion) {
        counts.pending += 1;
        return;
      }
      if (conclusion === 'success' || conclusion === 'neutral' || conclusion === 'skipped') {
        counts.success += 1;
      } else {
        counts.failure += 1;
      }
    });
    const total = counts.success + counts.failure + counts.pending;
    const state = counts.failure > 0
      ? 'failure'
      : (counts.pending > 0 ? 'pending' : (total > 0 ? 'success' : 'unknown'));
    return { state, total, ...counts };
  }

  const statusResp = await githubFetch(`${API_BASE}/repos/${repo.owner}/${repo.repo}/commits/${sha}/status`, accessToken);
  const statusJson = await jsonOrNull<JsonRecord>(statusResp);
  if (!statusResp.ok || !statusJson) return null;
  const statuses = Array.isArray(statusJson.statuses) ? (statusJson.statuses as unknown[]) : [];
  const counts = { success: 0, failure: 0, pending: 0 };
  statuses.forEach((s) => {
    const st = readString((s as JsonRecord | null)?.state);
    if (st === 'success') counts.success += 1;
    else if (st === 'failure' || st === 'error') counts.failure += 1;
    else if (st === 'pending') counts.pending += 1;
  });
  const total = counts.success + counts.failure + counts.pending;
  const state = counts.failure > 0
    ? 'failure'
    : (counts.pending > 0 ? 'pending' : (total > 0 ? 'success' : 'unknown'));
  return { state, total, ...counts };
};

export const listPullRequests = async (
  accessToken: string,
  directory: string,
  page: number = 1,
): Promise<GitHubPullRequestsListResult> => {
  const repo = await resolveRepoFromDirectory(directory);
  if (!repo) {
    return { connected: true, repo: null, prs: [] };
  }

  const url = new URL(`${API_BASE}/repos/${repo.owner}/${repo.repo}/pulls`);
  url.searchParams.set('state', 'open');
  url.searchParams.set('per_page', '50');
  url.searchParams.set('page', String(page));

  const resp = await githubFetch(url.toString(), accessToken);
  if (resp.status === 401) return { connected: false };

  const link = resp.headers.get('link') || '';
  const hasMore = /rel="next"/.test(link);
  const json = await jsonOrNull<unknown[]>(resp);
  if (!resp.ok || !Array.isArray(json)) throw new Error('Failed to load PRs');

  const prs = json.map((entry) => {
    const rec = entry && typeof entry === 'object' ? (entry as JsonRecord) : null;
    const number = typeof rec?.number === 'number' ? rec.number : 0;
    const mergedAt = readString(rec?.merged_at);
    const stateRaw = readString(rec?.state);
    const state = mergedAt ? 'merged' : (stateRaw === 'closed' ? 'closed' : 'open');

    const base = rec?.base && typeof rec.base === 'object' ? (rec.base as JsonRecord) : null;
    const head = rec?.head && typeof rec.head === 'object' ? (rec.head as JsonRecord) : null;

    return {
      number,
      title: readString(rec?.title) || '',
      url: readString(rec?.html_url) || '',
      state,
      draft: Boolean(rec?.draft),
      base: readString(base?.ref) || '',
      head: readString(head?.ref) || '',
      headSha: readString(head?.sha) || undefined,
      mergeable: typeof rec?.mergeable === 'boolean' ? rec.mergeable : null,
      mergeableState: readString(rec?.mergeable_state) || undefined,
      author: mapUser(rec?.user),
      headLabel: readString(head?.label) || undefined,
      headRepo: mapHeadRepo(head?.repo),
    } as GitHubPullRequestSummary;
  });

  return { connected: true, repo, prs, page, hasMore };
};

export const getPullRequestContext = async (
  accessToken: string,
  directory: string,
  number: number,
  includeDiff: boolean,
): Promise<GitHubPullRequestContextResult> => {
  const repo = await resolveRepoFromDirectory(directory);
  if (!repo) {
    return { connected: true, repo: null, pr: null };
  }

  const prResp = await githubFetch(`${API_BASE}/repos/${repo.owner}/${repo.repo}/pulls/${number}`, accessToken);
  if (prResp.status === 401) return { connected: false };
  const prJson = await jsonOrNull<JsonRecord>(prResp);
  if (!prResp.ok || !prJson) throw new Error('Failed to load PR');

  const merged = Boolean(prJson.merged_at) || Boolean(prJson.merged);
  const prState = readString(prJson.state);
  const state = merged ? 'merged' : (prState === 'closed' ? 'closed' : 'open');
  const base = prJson.base && typeof prJson.base === 'object' ? (prJson.base as JsonRecord) : null;
  const head = prJson.head && typeof prJson.head === 'object' ? (prJson.head as JsonRecord) : null;

  const pr: GitHubPullRequestSummary = {
    number: typeof prJson.number === 'number' ? prJson.number : number,
    title: readString(prJson.title) || '',
    url: readString(prJson.html_url) || '',
    state,
    draft: Boolean(prJson.draft),
    base: readString(base?.ref) || '',
    head: readString(head?.ref) || '',
    headSha: readString(head?.sha) || undefined,
    mergeable: typeof prJson.mergeable === 'boolean' ? prJson.mergeable : null,
    mergeableState: readString(prJson.mergeable_state) || undefined,
    author: mapUser(prJson.user),
    headLabel: readString(head?.label) || undefined,
    headRepo: mapHeadRepo(head?.repo),
    body: readString(prJson.body) || '',
    createdAt: readString(prJson.created_at) || undefined,
    updatedAt: readString(prJson.updated_at) || undefined,
  };

  const issueCommentsResp = await githubFetch(`${API_BASE}/repos/${repo.owner}/${repo.repo}/issues/${number}/comments?per_page=100`, accessToken);
  if (issueCommentsResp.status === 401) return { connected: false };
  const issueCommentsJson = await jsonOrNull<unknown[]>(issueCommentsResp);
  if (!issueCommentsResp.ok || !Array.isArray(issueCommentsJson)) throw new Error('Failed to load PR issue comments');
  const issueComments: GitHubIssueComment[] = issueCommentsJson
    .map((entry) => {
      const rec = entry && typeof entry === 'object' ? (entry as JsonRecord) : null;
      const id = typeof rec?.id === 'number' ? rec.id : 0;
      if (!id) return null;
      return {
        id,
        url: readString(rec?.html_url) || '',
        body: readString(rec?.body) || '',
        author: mapUser(rec?.user),
        createdAt: readString(rec?.created_at) || undefined,
        updatedAt: readString(rec?.updated_at) || undefined,
      };
    })
    .filter(Boolean) as GitHubIssueComment[];

  const reviewCommentsResp = await githubFetch(`${API_BASE}/repos/${repo.owner}/${repo.repo}/pulls/${number}/comments?per_page=100`, accessToken);
  if (reviewCommentsResp.status === 401) return { connected: false };
  const reviewCommentsJson = await jsonOrNull<unknown[]>(reviewCommentsResp);
  if (!reviewCommentsResp.ok || !Array.isArray(reviewCommentsJson)) throw new Error('Failed to load PR review comments');
  const reviewComments: GitHubPullRequestReviewComment[] = reviewCommentsJson
    .map((entry) => {
      const rec = entry && typeof entry === 'object' ? (entry as JsonRecord) : null;
      const id = typeof rec?.id === 'number' ? rec.id : 0;
      if (!id) return null;
      return {
        id,
        url: readString(rec?.html_url) || '',
        body: readString(rec?.body) || '',
        author: mapUser(rec?.user),
        path: readString(rec?.path) || undefined,
        line: typeof rec?.line === 'number' ? rec.line : null,
        position: typeof rec?.position === 'number' ? rec.position : null,
        createdAt: readString(rec?.created_at) || undefined,
        updatedAt: readString(rec?.updated_at) || undefined,
      };
    })
    .filter(Boolean) as GitHubPullRequestReviewComment[];

  const filesResp = await githubFetch(`${API_BASE}/repos/${repo.owner}/${repo.repo}/pulls/${number}/files?per_page=100`, accessToken);
  if (filesResp.status === 401) return { connected: false };
  const filesJson = await jsonOrNull<unknown[]>(filesResp);
  if (!filesResp.ok || !Array.isArray(filesJson)) throw new Error('Failed to load PR files');
  const files: GitHubPullRequestFile[] = filesJson
    .map((entry) => {
      const rec = entry && typeof entry === 'object' ? (entry as JsonRecord) : null;
      const filename = readString(rec?.filename);
      if (!filename) return null;
      return {
        filename,
        status: readString(rec?.status) || undefined,
        additions: typeof rec?.additions === 'number' ? rec.additions : undefined,
        deletions: typeof rec?.deletions === 'number' ? rec.deletions : undefined,
        changes: typeof rec?.changes === 'number' ? rec.changes : undefined,
        patch: readString(rec?.patch) || undefined,
      };
    })
    .filter(Boolean) as GitHubPullRequestFile[];

  const checks = pr.headSha ? await computeChecks(accessToken, repo, pr.headSha) : null;

  let diff: string | undefined;
  if (includeDiff) {
    const diffResp = await githubFetchText(`${API_BASE}/repos/${repo.owner}/${repo.repo}/pulls/${number}`, accessToken, 'application/vnd.github.v3.diff');
    if (diffResp.status === 401) return { connected: false };
    if (diffResp.ok) {
      diff = await diffResp.text().catch(() => undefined);
    }
  }

  return { connected: true, repo, pr, issueComments, reviewComments, files, diff, checks };
};
