import { expect, mock, test } from 'bun:test';

mock.module('@/sync/sync-refs', () => ({
    getSyncSessions: () => [{ id: 'ses_1', title: 'Prior work' }],
}));

const { compileChatComposerDelivery, legacyTextToAuthoredPlan } = await import('./chatComposerDelivery');

const agents = [{ name: 'worker', mode: 'subagent' }] as never;
const citation = {
    id: 'citation',
    filename: 'pick.ts:1-2',
    mimeType: 'text/plain',
    size: 0,
    source: 'vscode',
    vscodeSource: 'selection',
    vscodePath: 'src/pick.ts',
} as never;

test('direct compiler resolves authored delivery references', () => {
    const compiled = compileChatComposerDelivery({
        plan: {
            chunks: [{ provenance: 'authored', text: '\n@worker inspect @src/a.ts /review @session:ses_1 [pick.ts:1-2]\n', start: 0, end: 70 }],
            semantics: [],
        },
        agents,
        installedSkillNames: new Set(['review']),
        directory: '/project',
        root: '/project',
        confirmedFilePaths: ['src/a.ts'],
        citationAttachments: [citation],
    });

    expect(compiled.text).toBe('@worker inspect @src/a.ts /review @Prior work [src/pick.ts:1-2]');
    expect(compiled.agent).toBe('worker');
    expect(compiled.attachments.map((attachment) => attachment.serverPath)).toEqual(['/project/src/a.ts']);
    expect(compiled.attachments[0]?.dataUrl).toBe('file:///project/src/a.ts');
    expect(compiled.semantics).toEqual([
        { type: 'skill', skillName: 'review' },
        { type: 'session', sessionId: 'ses_1' },
    ]);
});

test('manual and auto legacy delivery compile text-only queue content', () => {
    for (const plan of [legacyTextToAuthoredPlan('@worker @src/file.ts /review @session:ses_1'), legacyTextToAuthoredPlan('@worker @src/file.ts')]) {
        const compiled = compileChatComposerDelivery({
            plan,
            agents,
            installedSkillNames: new Set(['review']),
            directory: '/project',
            root: '/project',
        });
        expect(compiled.agent).toBe('worker');
        expect(compiled.attachments[0]?.serverPath).toBe('/project/src/file.ts');
    }
});

test('compiler preserves Paste payload bytes while resolving authored session tokens', () => {
    const paste = '@session:ses_1 /review\n\n';
    const compiled = compileChatComposerDelivery({
        plan: {
            chunks: [
                { provenance: 'authored', text: '\nBefore @session:ses_1\n', start: 0, end: 23 },
                { provenance: 'reference-payload', text: paste, start: 23, end: 23 + paste.length, referenceId: 'paste' },
                { provenance: 'authored', text: '\nAfter\n', start: 23 + paste.length, end: 30 + paste.length },
            ],
            semantics: [],
        },
        agents,
        installedSkillNames: new Set(['review']),
        directory: '/project',
        root: '/project',
    });

    expect(compiled.text).toBe(`Before @Prior work\n${paste}\nAfter`);
    expect(compiled.semantics).toEqual([{ type: 'session', sessionId: 'ses_1' }]);
});
