import { describe, expect, test } from 'bun:test';

import {
    collectFileDropReferences,
    isAbsoluteFileDropPath,
    normalizeFileDropPath,
    parseFileDropReferences,
} from '../fileDropReferences';

describe('file drop references', () => {
    test('parses Finder file URLs and absolute paths', () => {
        expect(parseFileDropReferences('file:///Users/yee/Release%20Notes')).toEqual([
            'file:///Users/yee/Release%20Notes',
        ]);
        expect(parseFileDropReferences('/Users/yee/project/src/index.ts')).toEqual([
            '/Users/yee/project/src/index.ts',
        ]);
    });

    test('extracts file references from URI lists and VS Code payloads', () => {
        expect(parseFileDropReferences('# Finder URLs\nfile:///Users/yee/one.txt\nfile:///Users/yee/two')).toEqual([
            'file:///Users/yee/one.txt',
            'file:///Users/yee/two',
        ]);
        expect(parseFileDropReferences(JSON.stringify({ resources: ['file:///Users/yee/project', '/tmp/notes.md'] }))).toEqual([
            'file:///Users/yee/project',
            '/tmp/notes.md',
        ]);
    });

    test('ignores Markdown and JSX closing fragments', () => {
        expect(parseFileDropReferences('Dropped files:\n/>\nMore details')).toEqual([]);
        expect(parseFileDropReferences('/>')).toEqual([]);
    });

    test('treats text/plain as one direct file reference', () => {
        const transfer = {
            getData: (type: string) => {
                if (type === 'text/plain') {
                    return 'Notes:\n/tmp/one.txt\n/>\n/tmp/two.txt';
                }
                return '';
            },
        } as Pick<DataTransfer, 'getData'>;

        expect(collectFileDropReferences(transfer)).toEqual([]);

        const pathTransfer = {
            getData: (type: string) => type === 'text/plain' ? '/tmp/one.txt' : '',
        } as Pick<DataTransfer, 'getData'>;

        expect(collectFileDropReferences(pathTransfer)).toEqual(['/tmp/one.txt']);
    });

    test('reads structured VS Code payloads without parsing plain JSON text', () => {
        const payload = JSON.stringify({ resources: ['file:///Users/yee/project', '/tmp/notes.md'] });
        const transfer = {
            getData: (type: string) => type === 'CodeFiles' ? payload : '',
        } as Pick<DataTransfer, 'getData'>;
        const plainTransfer = {
            getData: (type: string) => type === 'text/plain' ? payload : '',
        } as Pick<DataTransfer, 'getData'>;

        expect(collectFileDropReferences(transfer)).toEqual([
            'file:///Users/yee/project',
            '/tmp/notes.md',
        ]);
        expect(collectFileDropReferences(plainTransfer)).toEqual([]);
    });

    test('reads every supported transfer type', () => {
        const transfer = {
            getData: (type: string) => type === 'text/uri-list'
                ? 'file:///Users/yee/notes.txt'
                : '',
        } as Pick<DataTransfer, 'getData'>;

        expect(collectFileDropReferences(transfer)).toEqual(['file:///Users/yee/notes.txt']);
    });

    test('normalizes paths for absolute file mentions', () => {
        expect(normalizeFileDropPath('file:///Users/yee/Release%20Notes')).toBe('/Users/yee/Release Notes');
        expect(normalizeFileDropPath('file:///C:/workspace/app.ts')).toBe('C:/workspace/app.ts');
        expect(normalizeFileDropPath('file://server/share/app.ts')).toBe('//server/share/app.ts');
        expect(isAbsoluteFileDropPath('/Users/yee/project')).toBe(true);
        expect(isAbsoluteFileDropPath('//server/share/project')).toBe(true);
        expect(isAbsoluteFileDropPath('project/src/index.ts')).toBe(false);
    });
});
