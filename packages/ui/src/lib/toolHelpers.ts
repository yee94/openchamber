export interface ToolMetadata {
  displayName: string;
  icon?: string;
  outputLanguage?: string;
  inputFields?: {
    key: string;
    label: string;
    type: 'command' | 'file' | 'pattern' | 'text' | 'code';
    language?: string;
  }[];
  category: 'file' | 'search' | 'code' | 'system' | 'ai' | 'web';
}

export const TOOL_METADATA: Record<string, ToolMetadata> = {

  read: {
    displayName: 'Read File',
    category: 'file',
    outputLanguage: 'auto',
    inputFields: [
      { key: 'filePath', label: 'File Path', type: 'file' },
      { key: 'offset', label: 'Start Line', type: 'text' },
      { key: 'limit', label: 'Lines to Read', type: 'text' }
    ]
  },
  write: {
    displayName: 'Write File',
    category: 'file',
    outputLanguage: 'auto',
    inputFields: [
      { key: 'filePath', label: 'File Path', type: 'file' },
      { key: 'content', label: 'Content', type: 'code' }
    ]
  },
  edit: {
    displayName: 'Edit File',
    category: 'file',
    outputLanguage: 'diff',
    inputFields: [
      { key: 'filePath', label: 'File Path', type: 'file' },
      { key: 'oldString', label: 'Find', type: 'code' },
      { key: 'newString', label: 'Replace', type: 'code' },
      { key: 'replaceAll', label: 'Replace All', type: 'text' }
    ]
  },
  multiedit: {
    displayName: 'Multi-Edit',
    category: 'file',
    outputLanguage: 'diff',
    inputFields: [
      { key: 'filePath', label: 'File Path', type: 'file' },
      { key: 'edits', label: 'Edits', type: 'code', language: 'json' }
    ]
  },

  bash: {
    displayName: 'Shell Command',
    category: 'system',
    outputLanguage: 'text',
    inputFields: [
      { key: 'command', label: 'Command', type: 'command', language: 'bash' },
      { key: 'description', label: 'Description', type: 'text' },
      { key: 'timeout', label: 'Timeout (ms)', type: 'text' }
    ]
  },

  grep: {
    displayName: 'Search Files',
    category: 'search',
    outputLanguage: 'text',
    inputFields: [
      { key: 'pattern', label: 'Pattern', type: 'pattern' },
      { key: 'path', label: 'Directory', type: 'file' },
      { key: 'include', label: 'Include Pattern', type: 'pattern' }
    ]
  },
  glob: {
    displayName: 'Find Files',
    category: 'search',
    outputLanguage: 'text',
    inputFields: [
      { key: 'pattern', label: 'Pattern', type: 'pattern' },
      { key: 'path', label: 'Directory', type: 'file' }
    ]
  },
  list: {
    displayName: 'List Directory',
    category: 'file',
    outputLanguage: 'text',
    inputFields: [
      { key: 'path', label: 'Directory', type: 'file' },
      { key: 'ignore', label: 'Ignore Patterns', type: 'pattern' }
    ]
  },

  task: {
    displayName: 'Agent Task',
    category: 'ai',
    outputLanguage: 'markdown',
    inputFields: [
      { key: 'description', label: 'Task', type: 'text' },
      { key: 'prompt', label: 'Instructions', type: 'text' },
      { key: 'subagent_type', label: 'Agent Type', type: 'text' }
    ]
  },

  webfetch: {
    displayName: 'Fetch URL',
    category: 'web',
    outputLanguage: 'auto',
    inputFields: [
      { key: 'url', label: 'URL', type: 'text' },
      { key: 'format', label: 'Format', type: 'text' },
      { key: 'timeout', label: 'Timeout', type: 'text' }
    ]
  },

   websearch: {
     displayName: 'Web Search',
     category: 'web',
     outputLanguage: 'markdown',
     inputFields: [
       { key: 'query', label: 'Search Query', type: 'text' },
       { key: 'numResults', label: 'Results Count', type: 'text' },
       { key: 'type', label: 'Search Type', type: 'text' }
     ]
   },
   codesearch: {
     displayName: 'Code Search',
     category: 'web',
     outputLanguage: 'markdown',
     inputFields: [
       { key: 'query', label: 'Search Query', type: 'text' },
       { key: 'tokensNum', label: 'Tokens', type: 'text' }
     ]
   },

   todowrite: {
     displayName: 'Update Todo List',
     category: 'system',
     outputLanguage: 'json',
     inputFields: [
       { key: 'todos', label: 'Todo Items', type: 'code', language: 'json' }
     ]
   },
   todoread: {
     displayName: 'Read Todo List',
     category: 'system',
     outputLanguage: 'json',
     inputFields: []
   },
   skill: {
     displayName: 'Load Skill',
     category: 'ai',
     outputLanguage: 'markdown',
     inputFields: [
       { key: 'name', label: 'Skill Name', type: 'text' }
     ]
   },
   question: {
     displayName: 'Question',
     category: 'ai',
     outputLanguage: 'text',
     inputFields: [
       { key: 'questions', label: 'Questions', type: 'code', language: 'json' }
     ]
   }
 };

export function getToolMetadata(toolName: string): ToolMetadata {
  return TOOL_METADATA[toolName] || {
    displayName: toolName.charAt(0).toUpperCase() + toolName.slice(1).replace(/-/g, ' '),
    category: 'system',
    outputLanguage: 'text',
    inputFields: []
  };
}

export function detectToolOutputLanguage(
  toolName: string,
  output: string,
  input?: Record<string, unknown>
): string {
  const metadata = getToolMetadata(toolName);

  if (metadata.outputLanguage === 'auto') {

    if (input?.filePath || input?.file_path || input?.sourcePath) {
      const filePath = (input.filePath || input.file_path || input.sourcePath) as string;
      const language = getLanguageFromExtension(filePath);
      if (language) return language;
    }

    if (toolName === 'webfetch') {
      if (output.trim().startsWith('{') || output.trim().startsWith('[')) {
        try {
          JSON.parse(output);
          return 'json';
        } catch { /* ignored */ }
      }
      if (output.trim().startsWith('<')) {
        return 'html';
      }
      if (output.includes('```')) {
        return 'markdown';
      }
    }

    return 'text';
  }

  return metadata.outputLanguage || 'text';
}

export function getLanguageFromExtension(filePath: string): string | null {
  const ext = filePath.split('.').pop()?.toLowerCase();

  const languageMap: Record<string, string> = {

    'js': 'javascript',
    'jsx': 'jsx',
    'ts': 'typescript',
    'tsx': 'tsx',
    'mjs': 'javascript',
    'cjs': 'javascript',

    'html': 'html',
    'htm': 'html',
    'css': 'css',
    'scss': 'scss',
    'sass': 'sass',
    'less': 'less',

    'json': 'json',
    'jsonc': 'json',
    'yaml': 'yaml',
    'yml': 'yaml',
    'toml': 'toml',
    'xml': 'xml',

    'py': 'python',
    'rb': 'ruby',
    'go': 'go',
    'rs': 'rust',
    'java': 'java',
    'kt': 'kotlin',
    'swift': 'swift',
    'c': 'c',
    'cpp': 'cpp',
    'cc': 'cpp',
    'h': 'c',
    'hpp': 'cpp',
    'cs': 'csharp',
    'php': 'php',
    'dart': 'dart',
    'r': 'r',
    'lua': 'lua',
    'vim': 'vim',

    'sh': 'bash',
    'bash': 'bash',
    'zsh': 'bash',
    'fish': 'bash',
    'ps1': 'powershell',

    'md': 'markdown',
    'mdx': 'markdown',
    'rst': 'text',
    'txt': 'text',

    'dockerfile': 'dockerfile',
    'makefile': 'makefile',
    'gitignore': 'text',
    'env': 'text',
    'conf': 'text',
    'cfg': 'text',
    'ini': 'ini',

    'sql': 'sql',

    'diff': 'diff',
    'patch': 'diff'
  };

  return languageMap[ext || ''] || null;
}

const IMAGE_EXTENSIONS = ['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'ico', 'bmp', 'avif'];

export function isImageFile(filePath: string): boolean {
  const ext = filePath.split('.').pop()?.toLowerCase();
  return IMAGE_EXTENSIONS.includes(ext || '');
}

export function getImageMimeType(filePath: string): string {
  const ext = filePath.split('.').pop()?.toLowerCase();
  const mimeMap: Record<string, string> = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'svg': 'image/svg+xml',
    'webp': 'image/webp',
    'ico': 'image/x-icon',
    'bmp': 'image/bmp',
    'avif': 'image/avif',
  };
  return mimeMap[ext || ''] || 'image/png';
}

export function formatToolInput(input: Record<string, unknown>, toolName: string): string {
  if (!input) return '';

  const getString = (key: string): string | null => {
    const val = input[key];
    return typeof val === 'string' ? val : (typeof val === 'number' ? String(val) : null);
  };

  if (toolName === 'bash') {
    const cmd = getString('command');
    if (cmd) return cmd;
  }

  if (toolName === 'task') {
    const prompt = getString('prompt');
    if (prompt) return prompt;
    const desc = getString('description');
    if (desc) return desc;
  }

  if ((toolName === 'edit' || toolName === 'multiedit') && typeof input === 'object') {
    const filePath = getString('filePath') || getString('file_path') || getString('path');
    if (filePath) {
      return `File path: ${filePath}`;
    }
  }

  if (toolName === 'write' && typeof input === 'object') {

    const content = getString('content');
    if (content) {
      return content;
    }
  }

  if (typeof input === 'object') {
    const entries = Object.entries(input)
      .filter(([, value]) => value !== undefined && value !== null && value !== '')
      .map(([key, value]) => {

        const formattedKey = key.replace(/([A-Z])/g, ' $1').replace(/_/g, ' ')
          .toLowerCase()
          .replace(/^./, str => str.toUpperCase());

        let formattedValue = value;
        if (typeof value === 'object') {
          formattedValue = JSON.stringify(value, null, 2);
        } else if (typeof value === 'boolean') {
          formattedValue = value ? 'Yes' : 'No';
        }

        return `${formattedKey}: ${formattedValue}`;
      });

    return entries.join('\n');
  }

  return String(input);
}
