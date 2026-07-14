import { describe, expect, test } from 'bun:test';
import { toggleComment } from '@codemirror/commands';
import { EditorState, type Transaction } from '@codemirror/state';

import { languageByExtension } from './languageByExtension';

const toggleCommentInDocument = (fileName: string, document: string) => {
  const language = languageByExtension(fileName);
  let state = EditorState.create({
    doc: document,
    extensions: language ? [language] : [],
  });

  const handled = toggleComment({
    state,
    dispatch: (transaction: Transaction) => {
      state = transaction.state;
    },
  });

  return { handled, document: state.doc.toString() };
};

describe('languageByExtension comment support', () => {
  test('toggles line comments in JSONC documents', () => {
    expect(toggleCommentInDocument('opencode.jsonc', '{')).toEqual({
      handled: true,
      document: '// {',
    });
  });

  test('keeps strict JSON without comment commands', () => {
    expect(toggleCommentInDocument('package.json', '{')).toEqual({
      handled: false,
      document: '{',
    });
  });
});
