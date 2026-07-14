import { describe, expect, it } from 'bun:test';
import {
  buildLatestTitleTranscript,
  canAutoRefreshSessionTitle,
  isDefaultSessionTitle,
  looksLikeMultiRunSessionTitle,
  remainingTitleThrottleMs,
  TITLE_THROTTLE_MS,
} from './runtime.js';

describe('session-title helpers', () => {
  it('detects OpenCode default titles', () => {
    expect(isDefaultSessionTitle('New session - 2026-07-10T12:00:00.000Z')).toBe(true);
    expect(isDefaultSessionTitle('Child session - 2026-07-10T12:00:00.000Z')).toBe(true);
    expect(isDefaultSessionTitle('Debugging production 500 errors')).toBe(false);
  });

  it('detects multi-run structural titles', () => {
    expect(looksLikeMultiRunSessionTitle('bench/anthropic/claude')).toBe(true);
    expect(looksLikeMultiRunSessionTitle('bench/g2/anthropic/claude/3')).toBe(true);
    expect(looksLikeMultiRunSessionTitle('bench/anthropic/claude/fusion')).toBe(true);
    expect(looksLikeMultiRunSessionTitle('Rate limiting implementation')).toBe(false);
  });

  it('protects manual renames after an auto title', () => {
    expect(canAutoRefreshSessionTitle('New session - 2026-07-10T12:00:00.000Z', '')).toBe(true);
    expect(canAutoRefreshSessionTitle('Auto title', 'Auto title')).toBe(true);
    expect(canAutoRefreshSessionTitle('My rename', 'Auto title')).toBe(false);
    expect(canAutoRefreshSessionTitle('bench/anthropic/claude', 'Auto title')).toBe(false);
  });

  it('computes remaining throttle window', () => {
    const now = 1_000_000;
    expect(remainingTitleThrottleMs(0, now)).toBe(0);
    expect(remainingTitleThrottleMs(now - TITLE_THROTTLE_MS, now)).toBe(0);
    expect(remainingTitleThrottleMs(now - 60_000, now)).toBe(TITLE_THROTTLE_MS - 60_000);
  });

  it('builds a transcript biased to the latest turns', () => {
    const messages = [
      {
        info: { id: 'u1', role: 'user' },
        parts: [{ type: 'text', text: 'hello world' }],
      },
      {
        info: { id: 'a1', role: 'assistant' },
        parts: [{ type: 'text', text: 'hi there' }],
      },
      {
        info: { id: 'u2', role: 'user' },
        parts: [{ type: 'text', text: 'add rate limiting' }],
      },
      {
        info: { id: 'a2', role: 'assistant' },
        parts: [{ type: 'text', text: 'implemented rate limit' }],
      },
    ];
    const result = buildLatestTitleTranscript(messages, { maxTurns: 2 });
    expect(result.realUserCount).toBe(2);
    expect(result.lastAssistantId).toBe('a2');
    expect(result.transcript).toContain('add rate limiting');
    expect(result.transcript).toContain('implemented rate limit');
  });

  it('keeps an earlier subject anchor when latest turns are wrap-up only', () => {
    const messages = [
      {
        info: { id: 'u1', role: 'user' },
        parts: [{ type: 'text', text: '实现会话标题主体性总结' }],
      },
      {
        info: { id: 'a1', role: 'assistant' },
        parts: [{ type: 'text', text: '开始改提示词和输入上下文' }],
      },
      {
        info: { id: 'u2', role: 'user' },
        parts: [{ type: 'text', text: '再补一下测试' }],
      },
      {
        info: { id: 'a2', role: 'assistant' },
        parts: [{ type: 'text', text: '测试已补' }],
      },
      {
        info: { id: 'u3', role: 'user' },
        parts: [{ type: 'text', text: '提交推送' }],
      },
      {
        info: { id: 'a3', role: 'assistant' },
        parts: [{ type: 'text', text: '已提交并推送' }],
      },
    ];
    const result = buildLatestTitleTranscript(messages, { maxTurns: 1 });
    expect(result.subjectAnchor).toBe('实现会话标题主体性总结');
    expect(result.transcript).toContain('Earlier subject anchor');
    expect(result.transcript).toContain('实现会话标题主体性总结');
    expect(result.transcript).toContain('提交推送');
    expect(result.languageSample).toBe('提交推送');
    expect(result.lastAssistantId).toBe('a3');
  });

  it('uses the latest real user text as the language sample', () => {
    const messages = [
      {
        info: { id: 'u1', role: 'user' },
        parts: [{ type: 'text', text: '修复会话标题语言' }],
      },
      {
        info: { id: 'a1', role: 'assistant' },
        parts: [{ type: 'text', text: 'I updated the title prompt in English.' }],
      },
    ];
    const result = buildLatestTitleTranscript(messages, { maxTurns: 1 });
    expect(result.languageSample).toBe('修复会话标题语言');
  });
});
