import { describe, expect, test } from 'bun:test';

import type { TurnRecord } from '../lib/turns/types';
import { splitTurnRecordsByLiveTail } from './useTurnRecords';

const turn = (turnId: string): TurnRecord => ({ turnId } as TurnRecord);

describe('splitTurnRecordsByLiveTail', () => {
    test('keeps the latest completed turn in virtualized history', () => {
        const first = turn('turn-1');
        const latest = turn('turn-2');

        expect(splitTurnRecordsByLiveTail([first, latest], false)).toEqual({
            staticTurns: [first, latest],
            streamingTurn: undefined,
        });
    });

    test('isolates only a live latest turn from virtualized history', () => {
        const first = turn('turn-1');
        const latest = turn('turn-2');

        expect(splitTurnRecordsByLiveTail([first, latest], true)).toEqual({
            staticTurns: [first],
            streamingTurn: latest,
        });
    });

    test('keeps a single completed turn in history', () => {
        const only = turn('turn-1');

        expect(splitTurnRecordsByLiveTail([only], false)).toEqual({
            staticTurns: [only],
            streamingTurn: undefined,
        });
    });
});
