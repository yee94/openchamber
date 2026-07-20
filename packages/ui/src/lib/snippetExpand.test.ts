import { describe, expect, test } from 'bun:test';
import type { Snippet } from '@/types/snippet';
import { expandSnippetsFromList } from './snippetExpand';

const snippet = (name: string, content: string, aliases: string[] = []): Snippet => ({
  name,
  content,
  aliases,
  filePath: `/tmp/${name}.md`,
  source: 'project',
});

describe('expandSnippetsFromList', () => {
  test('returns text unchanged when there is no hashtag', () => {
    expect(expandSnippetsFromList('hello', [])).toBe('hello');
  });

  test('expands known snippets locally', () => {
    const snippets = [snippet('review', 'Review carefully.')];
    expect(expandSnippetsFromList('Please #review this', snippets)).toBe('Please Review carefully. this');
  });

  test('returns null when a hashtag is unresolved', () => {
    expect(expandSnippetsFromList('Use #missing', [snippet('review', 'x')])).toBeNull();
  });

  test('resolves aliases and prepend blocks', () => {
    const snippets = [
      snippet('helper', '<prepend>Context</prepend>\nBody', ['help']),
    ];
    expect(expandSnippetsFromList('Go #help', snippets)).toBe('Context\n\nGo Body');
  });
});
