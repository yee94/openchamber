import { describe, expect, test } from 'bun:test';
import { consumesImmediateCommandText, getLocalChatCommand, IMMEDIATE_LOCAL_CHAT_COMMANDS, LOCAL_CHAT_COMMANDS, preservesComposerResources } from './localCommandClassifier';

describe('getLocalChatCommand', () => {
  test('classifies every local command', () => {
    for (const command of LOCAL_CHAT_COMMANDS) expect(getLocalChatCommand(`/${command} detail`, 'normal')).toBe(command);
  });
  test('keeps remote commands on the remote path', () => {
    expect(getLocalChatCommand('/remote-command', 'normal')).toBeNull();
    expect(getLocalChatCommand('/undo', 'shell')).toBeNull();
  });
  test('recognizes resource-preserving command boundaries', () => {
    expect(getLocalChatCommand('/compact', 'normal')).toBe('compact');
    expect(getLocalChatCommand('/fork from-here', 'normal')).toBe('fork');
    expect(getLocalChatCommand('/undo', 'normal')).toBe('undo');
  });
  test('keeps every local command resource-preserving and admits remote commands', () => {
    for (const command of LOCAL_CHAT_COMMANDS) expect(preservesComposerResources(`/${command}`, 'normal')).toBe(true);
    expect(preservesComposerResources('/remote-command', 'normal')).toBe(false);
  });
  test('consumes text only for immediate local actions', () => {
    for (const command of IMMEDIATE_LOCAL_CHAT_COMMANDS) expect(consumesImmediateCommandText(`/${command}`, 'normal')).toBe(true);
    expect(consumesImmediateCommandText('/summary', 'normal')).toBe(false);
    expect(consumesImmediateCommandText('/compact', 'shell')).toBe(false);
  });
  test('preserves shared composer resources for every local command outcome', () => {
    const consume = () => {
      let queue = 0; let legacyBinding = 0; let attachments = 0; let synthetic = 0; let inlineDrafts = 0;
      return {
        action: (text: string, outcome: 'success' | 'throw') => {
          try {
            if (outcome === 'throw') throw new Error('command failed');
          } catch {
            // The command action owns its failure presentation.
          }
          if (!preservesComposerResources(text, 'normal')) {
            queue += 1; legacyBinding += 1; attachments += 1; synthetic += 1; inlineDrafts += 1;
          }
        },
        calls: () => ({ queue, legacyBinding, attachments, synthetic, inlineDrafts }),
      };
    };

    for (const command of LOCAL_CHAT_COMMANDS) {
      for (const outcome of ['success', 'throw'] as const) {
        const recorder = consume();
        recorder.action(`/${command}`, outcome);
        expect(recorder.calls()).toEqual({ queue: 0, legacyBinding: 0, attachments: 0, synthetic: 0, inlineDrafts: 0 });
      }
    }

    const recorder = consume();
    recorder.action('/remote-command', 'success');
    expect(recorder.calls()).toEqual({ queue: 1, legacyBinding: 1, attachments: 1, synthetic: 1, inlineDrafts: 1 });
  });
});
