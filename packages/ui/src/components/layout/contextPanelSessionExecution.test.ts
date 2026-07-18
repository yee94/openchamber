import { describe, expect, test } from 'bun:test';

import { resolveContextPanelSessionExecution } from './contextPanelSessionExecution';

const message = (role: string, fields: Record<string, unknown> = {}) => ({
    info: { role, ...fields },
});

describe('resolveContextPanelSessionExecution', () => {
    test('prefers the newest assistant execution fields', () => {
        const result = resolveContextPanelSessionExecution([
            message('assistant', { agent: 'older-agent', providerID: 'older-provider', modelID: 'older-model' }),
            message('user', { agent: 'user-agent', providerID: 'user-provider', modelID: 'user-model' }),
            message('assistant', { agent: 'latest-agent', providerID: 'latest-provider', modelID: 'latest-model' }),
        ]);

        expect(result).toEqual({
            agentName: 'latest-agent',
            providerId: 'latest-provider',
            modelId: 'latest-model',
        });
    });

    test('fills missing assistant fields before consulting other messages', () => {
        const result = resolveContextPanelSessionExecution([
            message('assistant', { providerID: 'assistant-provider', modelID: 'assistant-model' }),
            message('user', { agent: 'user-agent', providerID: 'user-provider' }),
            message('assistant', { agent: 'latest-agent' }),
        ]);

        expect(result).toEqual({
            agentName: 'latest-agent',
            providerId: 'assistant-provider',
            modelId: 'assistant-model',
        });
    });

    test('filters empty values and supplements fields from other messages', () => {
        const result = resolveContextPanelSessionExecution([
            message('user', { providerID: ' fallback-provider ', modelID: 'fallback-model' }),
            message('assistant', { agent: '  ', providerID: '', modelID: '\n' }),
            message('tool', { agent: ' fallback-agent ' }),
        ]);

        expect(result).toEqual({
            agentName: 'fallback-agent',
            providerId: 'fallback-provider',
            modelId: 'fallback-model',
        });
    });
});
