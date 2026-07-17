import { useQuery } from '@tanstack/react-query';
import type { FilesAPI } from '@/lib/api/types';
import { getRegisteredRuntimeAPIs } from '@/contexts/runtimeAPIRegistry';
import { useRuntimeAPIs } from '@/hooks/useRuntimeAPIs';
import { runtimeFetch } from '@/lib/runtime-fetch';
import { queryKeys } from '@/lib/queryRuntime';
import { getRuntimeTransportIdentity } from '@/lib/runtime-switch';

export type ResolvedPlan =
  | { kind: 'resolved'; source: 'target' | 'repo' | 'home'; path: string; content: string }
  | { kind: 'missing'; candidates: readonly string[] };

type PlanQueryInput = {
  mode: 'target' | 'session';
  sessionId: string | null;
  scopeDirectory: string | null;
  targetPath: string | null;
  repoPath: string | null;
  homePath: string | null;
};

export const resolvePlanSource = (input: PlanQueryInput, path: string): 'target' | 'repo' | 'home' => {
  if (input.mode === 'target') return 'target';
  return path === input.repoPath ? 'repo' : 'home';
};

const readOptions = (scopeDirectory: string | null) => ({ optional: true, ...(scopeDirectory ? { directory: scopeDirectory } : {}) });

const readOptional = async (files: FilesAPI | undefined, path: string, scopeDirectory: string | null): Promise<string | null> => {
  if (files?.readFile) {
    const result = await files.readFile(path, readOptions(scopeDirectory));
    if (typeof result.exists !== 'boolean') throw new Error('Plan file read returned an invalid exists contract');
    return result.exists ? result.content : null;
  }
  const response = await runtimeFetch('/api/fs/read', {
    query: { path, optional: true },
    cache: 'no-store',
    headers: scopeDirectory ? { 'x-opencode-directory': scopeDirectory } : undefined,
  });
  if (!response.ok) throw new Error(`Failed to read plan file (${response.status})`);
  const exists = response.headers.get('x-openchamber-file-exists');
  if (exists === 'true') return response.text();
  if (exists === 'false') return null;
  throw new Error('Plan file read returned an invalid exists contract');
};

export const planResolvedQueryOptions = (
  files: FilesAPI | undefined,
  input: PlanQueryInput,
  transport = getRuntimeTransportIdentity(),
) => {
  const capturedFiles = files?.readFile ? files : getRegisteredRuntimeAPIs()?.files;
  return {
  queryKey: queryKeys.plans.resolved(input.mode, input.sessionId, input.scopeDirectory, input.targetPath, input.repoPath, input.homePath, transport),
  queryFn: async (): Promise<ResolvedPlan> => {
    if (input.mode === 'target') {
      if (!input.targetPath) throw new Error('A target plan path is required');
      const content = await readOptional(capturedFiles, input.targetPath, input.scopeDirectory);
      return content === null ? { kind: 'missing', candidates: [input.targetPath] } : { kind: 'resolved', source: 'target', path: input.targetPath, content };
    }
    if (!input.repoPath || !input.homePath) throw new Error('Session plan candidates are required');
    const repo = await readOptional(capturedFiles, input.repoPath, input.scopeDirectory);
    if (repo !== null) return { kind: 'resolved', source: 'repo', path: input.repoPath, content: repo };
    const home = await readOptional(capturedFiles, input.homePath, input.scopeDirectory);
    return home === null
      ? { kind: 'missing', candidates: [input.repoPath, input.homePath] }
      : { kind: 'resolved', source: 'home', path: input.homePath, content: home };
  },
  };
};

export const usePlanResolvedQuery = (input: PlanQueryInput, options: { enabled?: boolean } = {}) => {
  const { files } = useRuntimeAPIs();
  const transport = getRuntimeTransportIdentity();
  return useQuery({ ...planResolvedQueryOptions(files, input, transport), ...options });
};
