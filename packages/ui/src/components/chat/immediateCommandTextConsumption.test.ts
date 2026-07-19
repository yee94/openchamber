import { describe, expect, test } from 'bun:test';
import { consumeImmediateCommandText } from './immediateCommandTextConsumption';

type Harness = ReturnType<typeof createHarness>;

const createHarness = () => {
    let message = '/compact';
    const attachments = ['file.txt'];
    const inlineDrafts = ['comment'];
    const messageRef = { current: message };
    const consume = () => consumeImmediateCommandText({
        currentSessionId: 'source',
        messageRef,
        replacePlainDocument: (next) => { message = next; },
    });
    return {
        attachments,
        consume,
        get inlineDrafts() { return inlineDrafts; },
        get message() { return message; },
        messageRef,
    };
};

const assertConsumed = (harness: Harness) => {
    expect(harness.message).toBe('');
    expect(harness.messageRef.current).toBe('');
    expect(harness.attachments).toEqual(['file.txt']);
    expect(harness.inlineDrafts).toEqual(['comment']);
};

describe('consumeImmediateCommandText', () => {
    test('clears compact text and its source draft before a successful action', async () => {
        const harness = createHarness();
        expect(harness.consume()).toBe('source');
        await Promise.resolve();
        assertConsumed(harness);
    });

    test('keeps compact text consumed when the action fails', async () => {
        const harness = createHarness();
        harness.consume();
        await Promise.reject(new Error('compact failed')).catch(() => undefined);
        assertConsumed(harness);
    });


    test('leaves fork restoration available for the target session', () => {
        const harness = createHarness();
        harness.messageRef.current = '/fork';
        harness.consume();
        const pendingInputText = 'fork point text';
        assertConsumed(harness);
        expect(pendingInputText).toBe('fork point text');
        expect(pendingInputText).not.toContain('/fork');
    });
});
