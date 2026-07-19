import type { ComposerDocument } from './document';
import {
    COMPOSER_REFERENCE_LIMITS,
    contributeComposerReferenceCanonical,
    contributeComposerReferenceDirectSend,
    getComposerReferencePayloadBudget,
    type ComposerReferenceSemantic,
} from './extensions';

export type ComposerSendChunk =
    | { provenance: 'authored'; text: string; start: number; end: number }
    | { provenance: 'generated-reference'; text: string; start: number; end: number; referenceId: string; semantic: ComposerReferenceSemantic }
    | { provenance: 'reference-payload'; text: string; start: number; end: number; referenceId: string };

export interface ComposerSendPlan { chunks: ComposerSendChunk[]; semantics: ComposerReferenceSemantic[]; }
export type ComposerSendPlanResult = { ok: true; plan: ComposerSendPlan; text: string } | { ok: false; reason: 'invalid-references' | 'reference-budget-exceeded' | 'reference-payload-budget-exceeded' | 'canonical-output-too-large' };

export const compileComposerSendPlan = (document: ComposerDocument, mode: 'queue-canonical' | 'direct-send-display' = 'queue-canonical'): ComposerSendPlanResult => {
    if (document.references.length > COMPOSER_REFERENCE_LIMITS.referenceCount) return { ok: false, reason: 'reference-budget-exceeded' };
    const references = [...document.references].sort((left, right) => left.start - right.start);
    let previousEnd = 0;
    let opaquePayloadLength = 0;
    for (const reference of references) {
        if (reference.start < previousEnd || reference.start < 0 || reference.end <= reference.start || reference.end > document.text.length || document.text.slice(reference.start, reference.end) !== reference.display) return { ok: false, reason: 'invalid-references' };
        previousEnd = reference.end;
        const payloadBudget = getComposerReferencePayloadBudget(reference);
        opaquePayloadLength += payloadBudget?.category === 'opaque-text' ? payloadBudget.length : 0;
    }
    if (opaquePayloadLength > COMPOSER_REFERENCE_LIMITS.totalPastePayloadLength) return { ok: false, reason: 'reference-payload-budget-exceeded' };
    const chunks: ComposerSendChunk[] = [];
    const semantics: ComposerReferenceSemantic[] = [];
    let cursor = 0;
    for (const reference of references) {
        if (cursor < reference.start) chunks.push({ provenance: 'authored', text: document.text.slice(cursor, reference.start), start: cursor, end: reference.start });
        const contribution = mode === 'direct-send-display'
            ? contributeComposerReferenceDirectSend(reference)
            : contributeComposerReferenceCanonical(reference);
        if (contribution.semantic) {
            chunks.push({ provenance: 'generated-reference', text: contribution.text, start: reference.start, end: reference.end, referenceId: reference.id, semantic: contribution.semantic });
            semantics.push(contribution.semantic);
        } else {
            chunks.push({ provenance: 'reference-payload', text: contribution.text, start: reference.start, end: reference.end, referenceId: reference.id });
        }
        cursor = reference.end;
    }
    if (cursor < document.text.length) chunks.push({ provenance: 'authored', text: document.text.slice(cursor), start: cursor, end: document.text.length });
    const text = chunks.map((chunk) => chunk.text).join('');
    if (text.length > COMPOSER_REFERENCE_LIMITS.canonicalOutputLength) return { ok: false, reason: 'canonical-output-too-large' };
    return { ok: true, plan: { chunks, semantics }, text };
};

export interface DirectSendChunkTransform<Result> {
    transformAuthored: (text: string) => { text: string; result: Result };
}

/** Applies parsing only to authored text while preserving generated references and paste payloads byte-for-byte. */
export const transformDirectSendPlan = <Result>(plan: ComposerSendPlan, { transformAuthored }: DirectSendChunkTransform<Result>): { text: string; authoredResults: Result[]; allAuthored: boolean } => {
    const firstAuthored = plan.chunks[0]?.provenance === 'authored' ? 0 : -1;
    const lastIndex = plan.chunks.length - 1;
    const lastAuthored = plan.chunks[lastIndex]?.provenance === 'authored' ? lastIndex : -1;
    const authoredResults: Result[] = [];
    const text = plan.chunks.map((chunk, index) => {
        if (chunk.provenance !== 'authored') return chunk.text;
        let boundaryText = chunk.text;
        if (index === firstAuthored) boundaryText = boundaryText.replace(/^\n+/, '');
        if (index === lastAuthored) boundaryText = boundaryText.replace(/\n+$/, '');
        const transformed = transformAuthored(boundaryText);
        authoredResults.push(transformed.result);
        return transformed.text;
    }).join('');
    return { text, authoredResults, allAuthored: plan.chunks.every((chunk) => chunk.provenance === 'authored') };
};
