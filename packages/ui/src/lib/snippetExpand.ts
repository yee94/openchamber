import type { Snippet } from '@/types/snippet';

const HASHTAG_PATTERN = /#([a-z0-9_-]+)/gi;
const MAX_EXPANSION_COUNT = 15;

type SnippetBlocks = {
  inline: string;
  prepend: string[];
  append: string[];
};

const parseSnippetBlocks = (content: string): SnippetBlocks => {
  const blocks = { prepend: [] as string[], append: [] as string[] };
  let inline = content;
  for (const type of ['prepend', 'append'] as const) {
    const regex = new RegExp(`<${type}>([\\s\\S]*?)(?:<\\/${type}>|$)`, 'gi');
    inline = inline.replace(regex, (_match, value) => {
      const normalized = String(value).trim();
      if (normalized) blocks[type].push(normalized);
      return '';
    });
  }
  inline = inline.replace(/<inject>[\s\S]*?(?:<\/inject>|$)/gi, '').trim();
  return { inline, prepend: blocks.prepend, append: blocks.append };
};

const buildRegistry = (snippets: Snippet[]): Map<string, Snippet> => {
  const registry = new Map<string, Snippet>();
  const canonicalNames = new Set<string>();
  for (const snippet of snippets) {
    const key = snippet.name.toLowerCase();
    registry.set(key, snippet);
    canonicalNames.add(key);
  }
  for (const snippet of snippets) {
    for (const alias of snippet.aliases) {
      const aliasKey = alias.toLowerCase();
      if (!canonicalNames.has(aliasKey) && !registry.has(aliasKey)) {
        registry.set(aliasKey, snippet);
      }
    }
  }
  return registry;
};

const expandText = (
  text: string,
  registry: Map<string, Snippet>,
  expansionCounts: Map<string, number>,
  collector: { prepend: string[]; append: string[] },
): string => {
  let expanded = text;
  let changed = true;

  while (changed) {
    const previous = expanded;
    let loopDetected = false;
    HASHTAG_PATTERN.lastIndex = 0;

    expanded = expanded.replace(HASHTAG_PATTERN, (match, name, offset, input) => {
      if (name.toLowerCase() === 'skill' && input[offset + match.length] === '(') return match;
      const snippet = registry.get(name.toLowerCase());
      if (!snippet) return match;

      const key = snippet.name.toLowerCase();
      const count = (expansionCounts.get(key) || 0) + 1;
      if (count > MAX_EXPANSION_COUNT) {
        loopDetected = true;
        return match;
      }
      expansionCounts.set(key, count);

      const parsed = parseSnippetBlocks(snippet.content);
      for (const block of parsed.prepend) {
        collector.prepend.push(expandText(block, registry, expansionCounts, collector));
      }
      for (const block of parsed.append) {
        collector.append.push(expandText(block, registry, expansionCounts, collector));
      }
      return expandText(parsed.inline, registry, expansionCounts, collector);
    });

    changed = expanded !== previous && !loopDetected;
  }

  return expanded;
};

/**
 * Expand `#snippet` tokens from an already-loaded snippet list (mirrors
 * server expandSnippets). Returns null when a hashtag cannot be resolved
 * locally so the caller can fall back to the network expand endpoint.
 */
export const expandSnippetsFromList = (text: string, snippets: Snippet[]): string | null => {
  if (!/#([a-z0-9_-]+)/i.test(text)) return text;

  const registry = buildRegistry(snippets);
  const unresolved: string[] = [];
  HASHTAG_PATTERN.lastIndex = 0;
  let match: RegExpExecArray | null;
  while ((match = HASHTAG_PATTERN.exec(text)) !== null) {
    const name = match[1];
    if (name.toLowerCase() === 'skill' && text[match.index + match[0].length] === '(') continue;
    if (!registry.has(name.toLowerCase())) unresolved.push(name);
  }
  if (unresolved.length > 0) return null;

  const collector = { prepend: [] as string[], append: [] as string[] };
  const expanded = expandText(text || '', registry, new Map(), collector).trim();
  return [...collector.prepend, expanded, ...collector.append].filter(Boolean).join('\n\n');
};
