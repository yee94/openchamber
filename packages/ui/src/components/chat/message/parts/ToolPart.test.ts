import { describe, expect, test } from 'bun:test';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
    statusBarPopoverListClassName,
    statusBarPopoverRowClassName,
    todoListClassName,
    todoToolListClassName,
    todoToolScrollOptions,
} from '../../statusBarPopover';
import { readTaskTagSessionIdFromOutput } from './taskSessionIdParser';
import {
    getToolExpandedContentClassName,
    getToolScrollableSectionPaddingClassName,
    MOBILE_SHELL_CODE_LINE_HEIGHT,
    TOOL_EXPANDED_TIMELINE_CLASS_NAME,
} from './toolExpandedLayout';

const __dirname = dirname(fileURLToPath(import.meta.url));
const toolPartSource = readFileSync(join(__dirname, 'ToolPart.tsx'), 'utf-8');

describe('readTaskTagSessionIdFromOutput', () => {
    test('parses task tags without state attributes', () => {
        expect(readTaskTagSessionIdFromOutput('<task id="ses_abc123">')).toBe('ses_abc123');
    });

    test('parses task tags with additional attributes', () => {
        expect(readTaskTagSessionIdFromOutput('<task id="ses_def456" state="completed">')).toBe('ses_def456');
    });
});

describe('shared todo list layout', () => {
    test('popover and tool lists share row boundaries while the tool scroll container owns overflow', () => {
        expect(statusBarPopoverListClassName).toContain(todoListClassName);
        expect(todoToolListClassName).toContain(todoListClassName);
        expect(statusBarPopoverRowClassName).toContain('px-3 py-2');
        expect(todoToolScrollOptions).toEqual({
            className: 'p-0',
            maxHeightClass: 'max-h-[46vh]',
            disableHorizontal: true,
        });
    });

    test('Todo ToolPart uses the compact shared list and scroll options', () => {
        expect(toolPartSource).toContain('{ listClassName: todoToolListClassName }');
        expect(toolPartSource).toContain('todoToolScrollOptions,');
        expect(toolPartSource).toContain("getToolExpandedContentClassName(isMobile, 'todo')");
    });
});

describe('shared expanded tool layout', () => {
    test('all mobile tool content uses the compact Todo boundary and scroll padding', () => {
        expect(TOOL_EXPANDED_TIMELINE_CLASS_NAME).toBe('relative ml-2 pl-3');
        expect(getToolExpandedContentClassName(true)).toBe('relative flex min-w-0 flex-col gap-2 py-2');
        expect(getToolExpandedContentClassName(true, 'todo')).toBe('relative flex min-w-0 flex-col gap-2 py-2');
        expect(getToolScrollableSectionPaddingClassName(true)).toBe('p-0');
    });

    test('desktop layout stays unchanged and mobile Shell uses compact rhythm', () => {
        expect(getToolExpandedContentClassName(false)).toBe('relative flex flex-col gap-2 pr-2 pb-2 pt-2 pl-4');
        expect(getToolScrollableSectionPaddingClassName(false)).toBe('p-2');
        expect(getToolExpandedContentClassName(true, 'default', true)).toContain('gap-1');
        expect(MOBILE_SHELL_CODE_LINE_HEIGHT).toBe('1.25rem');
    });
});
