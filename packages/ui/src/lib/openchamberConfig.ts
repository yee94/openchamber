/**
 * OpenChamber project-level configuration service.
 * Manages .openchamber/openchamber.json file for project-specific settings.
 */

import { opencodeClient } from './opencode/client';
import type { FilesAPI, RuntimeAPIs } from './api/types';

const CONFIG_FILENAME = 'openchamber.json';
const CONFIG_DIR = '.openchamber';

/**
 * Get the runtime Files API if available (Desktop/VSCode).
 */
function getRuntimeFilesAPI(): FilesAPI | null {
  if (typeof window === 'undefined') return null;
  const apis = (window as typeof window & { __OPENCHAMBER_RUNTIME_APIS__?: RuntimeAPIs }).__OPENCHAMBER_RUNTIME_APIS__;
  if (apis?.files) {
    return apis.files;
  }
  return null;
}

export interface OpenChamberConfig {
  'setup-worktree'?: string[];
}

const normalize = (value: string): string => {
  if (!value) return '';
  const replaced = value.replace(/\\/g, '/');
  return replaced === '/' ? '/' : replaced.replace(/\/+$/, '');
};

const joinPath = (base: string, segment: string): string => {
  const normalizedBase = normalize(base);
  const cleanSegment = segment.replace(/\\/g, '/').replace(/^\/+/, '').replace(/\/+$/, '');
  if (!normalizedBase || normalizedBase === '/') {
    return `/${cleanSegment}`;
  }
  return `${normalizedBase}/${cleanSegment}`;
};

const getConfigPath = (projectDirectory: string): string => {
  return joinPath(joinPath(projectDirectory, CONFIG_DIR), CONFIG_FILENAME);
};

/**
 * Read the openchamber.json config file for a project.
 * Returns null if file doesn't exist or is invalid.
 */
export async function readOpenChamberConfig(projectDirectory: string): Promise<OpenChamberConfig | null> {
  const configPath = getConfigPath(projectDirectory);
  
  try {
    // Try runtime API first (Desktop/VSCode)
    const runtimeFiles = getRuntimeFilesAPI();
    if (runtimeFiles?.readFile) {
      try {
        const result = await runtimeFiles.readFile(configPath);
        if (!result.content.trim()) {
          return null;
        }
        const parsed = JSON.parse(result.content);
        if (!parsed || typeof parsed !== 'object') {
          return null;
        }
        return parsed as OpenChamberConfig;
      } catch {
        return null;
      }
    }

    // Fall back to web API
    const response = await fetch(`${getBaseUrl()}/fs/read?path=${encodeURIComponent(configPath)}`);
    if (!response.ok) {
      if (response.status === 404) {
        return null;
      }
      return null;
    }
    
    const text = await response.text();
    if (!text.trim()) {
      return null;
    }
    
    const parsed = JSON.parse(text);
    if (!parsed || typeof parsed !== 'object') {
      return null;
    }
    
    return parsed as OpenChamberConfig;
  } catch {
    return null;
  }
}

/**
 * Write the openchamber.json config file for a project.
 */
export async function writeOpenChamberConfig(
  projectDirectory: string, 
  config: OpenChamberConfig
): Promise<boolean> {
  const configPath = getConfigPath(projectDirectory);
  const configDir = joinPath(projectDirectory, CONFIG_DIR);
  
  try {
    // Ensure .openchamber directory exists
    await opencodeClient.createDirectory(configDir);
    
    // Try runtime API first (Desktop/VSCode)
    const runtimeFiles = getRuntimeFilesAPI();
    if (runtimeFiles?.writeFile) {
      try {
        const result = await runtimeFiles.writeFile(configPath, JSON.stringify(config, null, 2));
        return result.success;
      } catch (error) {
        console.error('Failed to write openchamber config via runtime API:', error);
        return false;
      }
    }
    
    // Fall back to web API
    const response = await fetch(`${getBaseUrl()}/fs/write`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        path: configPath,
        content: JSON.stringify(config, null, 2),
      }),
    });
    
    return response.ok;
  } catch (error) {
    console.error('Failed to write openchamber config:', error);
    return false;
  }
}

/**
 * Update specific keys in the config, preserving other values.
 */
export async function updateOpenChamberConfig(
  projectDirectory: string,
  updates: Partial<OpenChamberConfig>
): Promise<boolean> {
  const existing = await readOpenChamberConfig(projectDirectory) || {};
  const merged = { ...existing, ...updates };
  return writeOpenChamberConfig(projectDirectory, merged);
}

/**
 * Get worktree setup commands from config.
 */
export async function getWorktreeSetupCommands(projectDirectory: string): Promise<string[]> {
  const config = await readOpenChamberConfig(projectDirectory);
  return config?.['setup-worktree'] ?? [];
}

/**
 * Save worktree setup commands to config.
 */
export async function saveWorktreeSetupCommands(
  projectDirectory: string,
  commands: string[]
): Promise<boolean> {
  // Filter out empty commands
  const filtered = commands.filter(cmd => cmd.trim().length > 0);
  return updateOpenChamberConfig(projectDirectory, { 'setup-worktree': filtered });
}

/**
 * Substitute variables in a command string.
 * Supported variables:
 * - $ROOT_WORKTREE_PATH: The root project directory path
 */
export function substituteCommandVariables(
  command: string,
  variables: { rootWorktreePath: string }
): string {
  return command
    .replace(/\$ROOT_WORKTREE_PATH/g, variables.rootWorktreePath)
    .replace(/\$\{ROOT_WORKTREE_PATH\}/g, variables.rootWorktreePath);
}

function getBaseUrl(): string {
  const defaultBaseUrl = import.meta.env.VITE_OPENCODE_URL || '/api';
  if (defaultBaseUrl.startsWith('/')) {
    return defaultBaseUrl;
  }
  return defaultBaseUrl;
}
