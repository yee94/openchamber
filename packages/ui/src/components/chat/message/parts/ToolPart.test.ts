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
const mobileAppSource = readFileSync(join(__dirname, '../../../../apps/MobileApp.tsx'), 'utf-8');
const mobileChangesSurfaceSource = readFileSync(join(__dirname, '../../../../apps/MobileChangesSurface.tsx'), 'utf-8');
const diffViewSource = readFileSync(join(__dirname, '../../../views/DiffView.tsx'), 'utf-8');
const progressiveGroupSource = readFileSync(join(__dirname, 'ProgressiveGroup.tsx'), 'utf-8');

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

describe('apply_patch navigation', () => {
    test('routes dedicated mobile clicks to the complete current-turn diff', () => {
        const clickHandlerStart = toolPartSource.indexOf('const handleMainClick');
        const fileNavigationStart = toolPartSource.indexOf('let filePath: unknown;', clickHandlerStart);
        const applyPatchNavigation = toolPartSource.slice(clickHandlerStart, fileNavigationStart);
        const fileNavigationEnd = toolPartSource.indexOf('if (!isFileNavTool)', fileNavigationStart);
        const fileNavigation = toolPartSource.slice(fileNavigationStart, fileNavigationEnd);

        expect(clickHandlerStart).toBeGreaterThan(-1);
        expect(fileNavigationStart).toBeGreaterThan(clickHandlerStart);
        expect(applyPatchNavigation).toContain("if (part.tool === 'apply_patch' && mobileActions)");
        expect(applyPatchNavigation).toContain('mobileActions.openTurnDiff(messageId);');
        expect(applyPatchNavigation.indexOf('mobileActions.openTurnDiff(messageId);')).toBeLessThan(applyPatchNavigation.indexOf('openContextPanelTab'));
        expect(fileNavigation).toContain('mobileActions.openChanges({ diffPath: relativePath, staged: false, targetLine });');
        expect(fileNavigation.indexOf('mobileActions.openChanges')).toBeLessThan(fileNavigation.indexOf("navigateToDiff(relativePath, false, 'turn', targetLine)"));
    });

    test('keeps the owning assistant message id when memoized tool rows update', () => {
        expect(toolPartSource).toContain('&& prev.messageId === next.messageId');
        expect(progressiveGroupSource).toContain('&& prev.activity.messageId === next.activity.messageId');
    });

    test('presents every current-turn diff in a closable high motion sheet', () => {
        const turnDiffStart = mobileAppSource.indexOf('<MobileResizableSheet\n            id={MOBILE_TURN_DIFF_WINDOW_ID}');
        const turnDiffEnd = mobileAppSource.indexOf('{changesOpen && pendingChangesDiff ? (', turnDiffStart);
        const turnDiffPresentation = mobileAppSource.slice(turnDiffStart, turnDiffEnd);

        expect(turnDiffStart).toBeGreaterThan(-1);
        expect(turnDiffEnd).toBeGreaterThan(turnDiffStart);
        expect(turnDiffPresentation).toContain('<MobileResizableSheet');
        expect(turnDiffPresentation).toContain('open={turnDiffOpen}');
        expect(turnDiffPresentation).toContain('resizeAriaLabel={t(\'mobile.changes.sheet.resizeAria\')}');
        expect(turnDiffPresentation).toContain('initiallyExpanded');
        expect(turnDiffPresentation).toContain('<DiffView hideStackedFileSidebar diffScope="turn" turnMessageId={turnDiffMessageId} flushContent />');
        expect(mobileAppSource).toContain('|| turnDiffOpen');
        expect(mobileAppSource).toContain('if (turnDiffOpen) {');
        expect(diffViewSource).toContain("showFileActions={activeDiffScope !== 'turn'}");
        expect(diffViewSource).toContain('sessionMessages.findIndex((message) => message.id === turnMessageId)');
    });

    test('presents a direct mobile diff in the shared resizable sheet', () => {
        const directDiffStart = mobileAppSource.indexOf('{changesOpen && pendingChangesDiff ? (');
        const directDiffEnd = mobileAppSource.indexOf(') : changesOpen ? (', directDiffStart);
        const directDiffPresentation = mobileAppSource.slice(directDiffStart, directDiffEnd);

        expect(directDiffStart).toBeGreaterThan(-1);
        expect(directDiffEnd).toBeGreaterThan(directDiffStart);
        expect(directDiffPresentation).toContain('<MobileResizableSheet');
        expect(directDiffPresentation).toContain('resizeAriaLabel={t(\'mobile.changes.sheet.resizeAria\')}');
        expect(directDiffPresentation).toContain('initiallyExpanded');
        expect(directDiffPresentation).toContain('hideDiffHeader');
        expect(mobileChangesSurfaceSource).toContain('hideHeader={hideDiffHeader}');
        expect(mobileChangesSurfaceSource).toContain('p-3 pwa-overlay-scroll');
    });
});
