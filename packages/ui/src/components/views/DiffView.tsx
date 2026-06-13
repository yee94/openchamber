import React from 'react';

import { useUIStore } from '@/stores/useUIStore';
import { useEffectiveDirectory } from '@/hooks/useEffectiveDirectory';
import { useGitStore, useGitStatus, useIsGitRepo, useGitFileCount, useGitLoadingStatus } from '@/stores/useGitStore';
import { cn } from '@/lib/utils';
import type { GitStatus } from '@/lib/api/types';
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuRadioGroup,
    DropdownMenuRadioItem,
    DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Button } from '@/components/ui/button';
import { toast } from '@/components/ui';

import { ScrollableOverlay } from '@/components/ui/ScrollableOverlay';
import { getLanguageFromExtension, isImageFile } from '@/lib/toolHelpers';
import { useRuntimeAPIs } from '@/hooks/useRuntimeAPIs';
import { DiffViewToggle } from '@/components/chat/message/DiffViewToggle';
import type { DiffViewMode } from '@/components/chat/message/types';
import { PierreDiffViewer } from './PierreDiffViewer';
import { useDeviceInfo } from '@/lib/device';
import { FileTypeIcon } from '@/components/icons/FileTypeIcon';
import { Icon } from "@/components/icon/Icon";
import { getContextFileOpenFailureMessage, validateContextFileOpen } from '@/lib/contextFileOpenGuard';
import { toAbsoluteFilePath } from '@/lib/path-utils';
import { sessionEvents } from '@/lib/sessionEvents';
import { useI18n } from '@/lib/i18n';
import type { I18nKey } from '@/lib/i18n/store';
import { fileDiffFromPatch } from '@/lib/diff/patchFileDiff';
import type { FileDiffMetadata } from '@pierre/diffs';

// Minimum width for side-by-side diff view (px)
const SIDE_BY_SIDE_MIN_WIDTH = 1100;
const DIFF_REQUEST_TIMEOUT_MS = 15000;
const LARGE_DIFF_CHANGED_LINES = 500;
const STACKED_DIFF_MOUNT_MARGIN = 300;
const FULL_CONTEXT_DIFF_LINES = 1_000_000;

// Perf: limit concurrent expanded diffs in stacked view.
// Expanding many diffs mounts many Pierre instances + lots of DOM.
const getStackedViewDefaultExpandedCount = (fileCount: number): number => {
    if (fileCount <= 6) return fileCount;
    if (fileCount <= 12) return 6;
    if (fileCount <= 25) return 4;
    return 2;
};

type FileEntry = GitStatus['files'][number] & {
    insertions: number;
    deletions: number;
    isNew: boolean;
};

type DiffData = { original: string; modified: string; isBinary?: boolean; patch?: string; fileDiff?: FileDiffMetadata };
type DiffScope = 'all' | 'staged' | 'working';

const BinaryDiffPlaceholder = React.memo(() => {
    const { t } = useI18n();
    return (
        <div className="rounded-lg border border-border/60 bg-background px-3 py-2">
            <div className="typography-meta text-muted-foreground">{t('diffView.binary.unavailable')}</div>
        </div>
    );
});

type ChangeDescriptor = {
    code: string;
    color: string;
    descriptionKey: I18nKey;
};

const CHANGE_DESCRIPTORS: Record<string, ChangeDescriptor> = {
    '?': { code: '?', color: 'var(--status-info)', descriptionKey: 'diffView.change.untracked' },
    A: { code: 'A', color: 'var(--status-success)', descriptionKey: 'diffView.change.new' },
    D: { code: 'D', color: 'var(--status-error)', descriptionKey: 'diffView.change.deleted' },
    R: { code: 'R', color: 'var(--status-info)', descriptionKey: 'diffView.change.renamed' },
    C: { code: 'C', color: 'var(--status-info)', descriptionKey: 'diffView.change.copied' },
    M: { code: 'M', color: 'var(--status-warning)', descriptionKey: 'diffView.change.modified' },
};

const DEFAULT_CHANGE_DESCRIPTOR = CHANGE_DESCRIPTORS.M;

const getChangeSymbol = (file: GitStatus['files'][number]): string => {
    const indexCode = file.index?.trim();
    const workingCode = file.working_dir?.trim();

    if (indexCode && indexCode !== '?') return indexCode.charAt(0);
    if (workingCode) return workingCode.charAt(0);

    return indexCode?.charAt(0) || workingCode?.charAt(0) || 'M';
};

const describeChange = (file: GitStatus['files'][number]): ChangeDescriptor => {
    const symbol = getChangeSymbol(file);
    return CHANGE_DESCRIPTORS[symbol] ?? DEFAULT_CHANGE_DESCRIPTOR;
};

const isNewStatusFile = (file: GitStatus['files'][number]): boolean => {
    const { index, working_dir: workingDir } = file;
    return index === 'A' || workingDir === 'A' || index === '?' || workingDir === '?';
};

const isStagedStatusFile = (file: GitStatus['files'][number]): boolean => {
    const indexCode = file.index?.trim();
    return Boolean(indexCode && indexCode !== '?');
};

const isWorkingStatusFile = (file: GitStatus['files'][number]): boolean => {
    const workingCode = file.working_dir?.trim();
    return Boolean(workingCode) || file.index === '?';
};

const toAbsolutePath = (directory: string, filePath: string): string => {
    return toAbsoluteFilePath(directory, filePath);
};

const normalizePath = (value?: string | null): string =>
    (value || '').replace(/\\/g, '/').replace(/\/+$/, '');

const getFirstChangedModifiedLine = (original: string, modified: string): number => {
    const originalLines = original.split('\n');
    const modifiedLines = modified.split('\n');
    const sharedLength = Math.min(originalLines.length, modifiedLines.length);

    for (let index = 0; index < sharedLength; index += 1) {
        if (originalLines[index] !== modifiedLines[index]) {
            return index + 1;
        }
    }

    if (modifiedLines.length > originalLines.length) {
        return originalLines.length + 1;
    }

    if (originalLines.length > modifiedLines.length) {
        return Math.max(1, modifiedLines.length);
    }

    return 1;
};

const getFirstVisibleModifiedLineFromPatch = (patch: string): number | null => {
    if (!patch) {
        return null;
    }

    const match = patch.match(/@@\s*-\d+(?:,\d+)?\s+\+(\d+)(?:,\d+)?\s*@@/m);
    if (!match) {
        return null;
    }

    const parsed = Number.parseInt(match[1], 10);
    if (!Number.isFinite(parsed) || parsed < 1) {
        return null;
    }

    return parsed;
};

const isBinaryPatch = (patch: string): boolean =>
    /^Binary files .+ differ$/m.test(patch) || /^GIT binary patch$/m.test(patch);

const createTextDiffDataFromPatch = (filePath: string, patch: string): DiffData => {
    if (isBinaryPatch(patch)) {
        return { original: '', modified: '', isBinary: true, patch };
    }

    return {
        original: '',
        modified: '',
        patch,
        fileDiff: fileDiffFromPatch(filePath, patch),
    };
};

const formatDiffTotals = (
    insertions?: number,
    deletions?: number,
    options?: { shrink?: boolean; className?: string },
) => {
    const added = insertions ?? 0;
    const removed = deletions ?? 0;
    if (!added && !removed) return null;
    return (
        <span
            className={cn(
                'typography-meta flex items-center gap-1 text-xs whitespace-nowrap',
                options?.shrink ? 'min-w-0 overflow-hidden' : 'flex-shrink-0',
                options?.className,
            )}
        >
            {added ? <span style={{ color: 'var(--status-success)' }}>+{added}</span> : null}
            {removed ? <span style={{ color: 'var(--status-error)' }}>-{removed}</span> : null}
        </span>
    );
};

const DiffFilePathLabel = React.memo<{
    path: string;
    className?: string;
}>(({ path, className }) => {
    const lastSlash = path.lastIndexOf('/');
    if (lastSlash === -1) {
        return (
            <span
                className={cn('block min-w-0 truncate typography-ui-label text-foreground', className)}
                title={path}
                style={{ direction: 'rtl', textAlign: 'left', unicodeBidi: 'plaintext' }}
            >
                {path}
            </span>
        );
    }

    const dir = path.slice(0, lastSlash);
    const name = path.slice(lastSlash + 1);

    return (
        <span
            className={cn('flex min-w-0 items-baseline overflow-hidden typography-ui-label', className)}
            title={path}
        >
            <span
                className="min-w-0 truncate text-muted-foreground"
                style={{ direction: 'rtl', textAlign: 'left', unicodeBidi: 'plaintext' }}
            >
                {dir}
            </span>
            <span className="flex-shrink-0">
                <span className="text-muted-foreground">/</span>
                <span className="text-foreground">{name}</span>
            </span>
        </span>
    );
});

interface FileSelectorProps {
    changedFiles: FileEntry[];
    selectedFile: string | null;
    selectedFileEntry: FileEntry | null;
    onSelectFile: (path: string) => void;
    className?: string;
}

const FileSelector = React.memo<FileSelectorProps>(({
    changedFiles,
    selectedFile,
    selectedFileEntry,
    onSelectFile,
    className,
}) => {
    const { t } = useI18n();

    if (changedFiles.length === 0) return null;

    return (
        <DropdownMenu>
            <DropdownMenuTrigger asChild>
                <button className={cn(
                    'diff-toolbar__file-trigger flex h-7 min-w-[3.75rem] max-w-full items-center gap-2 rounded-lg border border-input bg-transparent px-2 typography-ui-label text-foreground outline-none hover:bg-interactive-hover hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring',
                    className,
                )}>
                    {selectedFileEntry ? (
                        <div className="diff-toolbar__file-trigger-content flex min-w-0 flex-1 items-center gap-2">
                            <FileTypeIcon filePath={selectedFileEntry.path} className="h-3.5 w-3.5 flex-shrink-0" />
                            <DiffFilePathLabel path={selectedFileEntry.path} className="diff-toolbar__file-label min-w-0 flex-1" />
                            {formatDiffTotals(selectedFileEntry.insertions, selectedFileEntry.deletions, { shrink: true, className: 'diff-toolbar__file-stats' })}
                        </div>
                    ) : (
                        <span className="min-w-0 truncate text-muted-foreground">{t('diffView.selector.selectFile')}</span>
                    )}
                    <Icon name="arrow-down-s" className="size-4 flex-shrink-0 opacity-50" />
                </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent className="max-h-[70vh] w-[min(max(var(--anchor-width),18rem),36rem,calc(100vw-2rem))] max-w-[calc(100vw-2rem)] overflow-y-auto">
                <DropdownMenuRadioGroup value={selectedFile ?? ''} onValueChange={onSelectFile}>
                    {changedFiles.map((file) => (
                        <DropdownMenuRadioItem key={file.path} value={file.path} className="min-w-0 items-center">
                            <div className="flex w-full min-w-0 items-center gap-2.5">
                                <FileTypeIcon filePath={file.path} className="h-3.5 w-3.5 flex-shrink-0" />
                                <DiffFilePathLabel path={file.path} className="flex-1" />
                                {formatDiffTotals(file.insertions, file.deletions)}
                            </div>
                        </DropdownMenuRadioItem>
                    ))}
                </DropdownMenuRadioGroup>
            </DropdownMenuContent>
        </DropdownMenu>
    );
});

interface ChangeScopeSelectorProps {
    scope: Extract<DiffScope, 'working' | 'staged'>;
    workingCount: number;
    stagedCount: number;
    onScopeChange?: (scope: Extract<DiffScope, 'working' | 'staged'>) => void;
}

const ChangeScopeSelector = React.memo<ChangeScopeSelectorProps>(({
    scope,
    workingCount,
    stagedCount,
    onScopeChange,
}) => {
    const { t } = useI18n();
    const currentCount = scope === 'staged' ? stagedCount : workingCount;
    const currentLabel = scope === 'staged' ? t('diffView.scope.staged') : t('diffView.scope.changed');

    return (
        <DropdownMenu>
            <DropdownMenuTrigger asChild>
                <button
                    type="button"
                    className="flex h-7 flex-shrink-0 items-center gap-1.5 rounded-md px-2 typography-ui-label font-semibold text-foreground outline-none hover:bg-interactive-hover focus-visible:ring-2 focus-visible:ring-ring"
                    aria-label={t('diffView.scope.selectorAria')}
                >
                    <span className="whitespace-nowrap">
                        {currentLabel}<span className="diff-toolbar__scope-count">: {currentCount}</span>
                    </span>
                    <Icon name="arrow-down-s" className="size-4 flex-shrink-0 opacity-60" />
                </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="start" className="w-40">
                <DropdownMenuRadioGroup
                    value={scope}
                    onValueChange={(value) => {
                        if (value === 'working' || value === 'staged') {
                            onScopeChange?.(value);
                        }
                    }}
                >
                    <DropdownMenuRadioItem value="working">
                        <span className="flex min-w-0 flex-1 items-center justify-between gap-3">
                            <span>{t('diffView.scope.changed')}</span>
                            <span className="typography-meta text-muted-foreground">{workingCount}</span>
                        </span>
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value="staged">
                        <span className="flex min-w-0 flex-1 items-center justify-between gap-3">
                            <span>{t('diffView.scope.staged')}</span>
                            <span className="typography-meta text-muted-foreground">{stagedCount}</span>
                        </span>
                    </DropdownMenuRadioItem>
                </DropdownMenuRadioGroup>
            </DropdownMenuContent>
        </DropdownMenu>
    );
});

interface FileListProps {
    changedFiles: FileEntry[];
    selectedFile: string | null;
    onSelectFile: (path: string) => void;
}

const FileList = React.memo<FileListProps>(({
    changedFiles,
    selectedFile,
    onSelectFile,
}) => {
    const { t } = useI18n();
    if (changedFiles.length === 0) return null;

    return (
        <ScrollableOverlay outerClassName="flex-1 min-h-0" className="px-2 py-2">
            <ul className="flex flex-col gap-1">
                {changedFiles.map((file) => {
                    const descriptor = describeChange(file);
                    const isActive = selectedFile === file.path;

                    return (
                        <li key={file.path}>
                            <button
                                type="button"
                                onClick={() => onSelectFile(file.path)}
                                className={cn(
                                    'flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left transition-colors',
                                    isActive
                                        ? 'bg-interactive-selection text-interactive-selection-foreground'
                                        : 'text-muted-foreground hover:bg-interactive-hover hover:text-foreground'
                                )}
                            >
                                <FileTypeIcon filePath={file.path} className="h-3.5 w-3.5 flex-shrink-0" />
                                <span
                                    className="typography-micro font-semibold w-4 text-center uppercase"
                                    style={{ color: descriptor.color }}
                                    title={t(descriptor.descriptionKey)}
                                    aria-label={t(descriptor.descriptionKey)}
                                >
                                    {descriptor.code}
                                </span>
                                <span
                                    className="min-w-0 flex-1 truncate typography-meta"
                                    style={{ direction: 'rtl', textAlign: 'left', unicodeBidi: 'plaintext' }}
                                    title={file.path}
                                >
                                    {file.path}
                                </span>
                                {formatDiffTotals(file.insertions, file.deletions)}
                            </button>
                        </li>
                    );
                })}
            </ul>
        </ScrollableOverlay>
    );
});

// Image diff viewer for binary image files
interface InlineImageDiffViewerProps {
    filePath: string;
    diff: DiffData;
    renderSideBySide: boolean;
}

const InlineImageDiffViewer = React.memo<InlineImageDiffViewerProps>(({
    filePath,
    diff,
    renderSideBySide,
}) => {
    const { t } = useI18n();
    const hasOriginal = diff.original.length > 0;
    const hasModified = diff.modified.length > 0;

    const containerClass = renderSideBySide
        ? 'flex flex-row gap-6 items-start justify-center'
        : 'flex flex-col gap-4 items-center';

    const imageContainerClass = renderSideBySide
        ? 'flex flex-col items-center gap-2 flex-1 min-w-0'
        : 'flex flex-col items-center gap-2';

    return (
        <div className="w-full overflow-auto p-4" style={{ contain: 'layout' }}>
            <div className={containerClass}>
                {hasOriginal && (
                    <div className={imageContainerClass}>
                        <span className="typography-meta text-muted-foreground font-medium">{t('diffView.image.original')}</span>
                        <img
                            src={diff.original}
                            alt={t('diffView.image.originalAlt', { path: filePath })}
                            className={renderSideBySide ? "max-w-full max-h-[70vh] object-contain" : "max-w-full object-contain"}
                            style={{ imageRendering: 'auto' }}
                        />
                    </div>
                )}
                {hasModified && (
                    <div className={imageContainerClass}>
                        <span className="typography-meta text-muted-foreground font-medium">
                            {hasOriginal ? t('diffView.image.modified') : t('diffView.image.new')}
                        </span>
                        <img
                            src={diff.modified}
                            alt={t('diffView.image.modifiedAlt', { path: filePath })}
                            className={renderSideBySide ? "max-w-full max-h-[70vh] object-contain" : "max-w-full object-contain"}
                            style={{ imageRendering: 'auto' }}
                        />
                    </div>
                )}
            </div>
        </div>
    );
});

interface InlineDiffViewerProps {
    filePath: string;
    diff: DiffData;
    renderSideBySide: boolean;
    wrapLines: boolean;
}

const InlineDiffViewer = React.memo<InlineDiffViewerProps>(({ 
    filePath,
    diff,
    renderSideBySide,
    wrapLines,
}) => {
    const language = React.useMemo(
        () => getLanguageFromExtension(filePath) || 'text',
        [filePath]
    );

    if (diff.isBinary) {
        return <BinaryDiffPlaceholder />;
    }

    if (isImageFile(filePath)) {
        return (
            <InlineImageDiffViewer
                filePath={filePath}
                diff={diff}
                renderSideBySide={renderSideBySide}
            />
        );
    }

    return (
        <div className="w-full" style={{ contain: 'layout' }}>
            <PierreDiffViewer
                original={diff.original}
                modified={diff.modified}
                fileDiff={diff.fileDiff}
                language={language}
                fileName={filePath}
                renderSideBySide={renderSideBySide}
                wrapLines={wrapLines}
                layout="inline"
            />
        </div>
    );
});

interface MultiFileDiffEntryProps {
    directory: string;
    file: FileEntry;
    layout: 'inline' | 'side-by-side';
    wrapLines: boolean;
    isSelected: boolean;
    isExpanded: boolean;
    isMounted: boolean;
    onSelect: (path: string) => void;
    onExpandedChange: (path: string, expanded: boolean) => void;
    registerSectionRef: (path: string, node: HTMLDivElement | null) => void;
    showOpenInEditorAction?: boolean;
    isOpeningInEditor?: boolean;
    onOpenInEditor?: (filePath: string, diffData: DiffData | null) => void;
    staged?: boolean;
    stagedRevision?: number;
}

const MultiFileDiffEntry = React.memo<MultiFileDiffEntryProps>(({
    directory,
    file,
    layout,
    wrapLines,
    isSelected,
    isExpanded,
    isMounted,
    onSelect,
    onExpandedChange,
    registerSectionRef,
    showOpenInEditorAction = false,
    isOpeningInEditor = false,
    onOpenInEditor,
    staged = false,
    stagedRevision = 0,
}) => {
    const { t } = useI18n();
    const { git } = useRuntimeAPIs();
    const cachedDiff = useGitStore(
        React.useCallback((state) => {
            return state.directories.get(directory)?.diffCache.get(file.path) ?? null;
        }, [directory, file.path])
    );
    const setDiff = useGitStore((state) => state.setDiff);
    const setDiffFileLayout = useUIStore((state) => state.setDiffFileLayout);

    const [diffRetryNonce, setDiffRetryNonce] = React.useState(0);
    const [diffLoadError, setDiffLoadError] = React.useState<string | null>(null);
    const [isLoading, setIsLoading] = React.useState(false);
    const [forceRenderLarge, setForceRenderLarge] = React.useState(false);
    const [localDiffData, setLocalDiffData] = React.useState<DiffData | null>(null);
    const [stagedDiffData, setStagedDiffData] = React.useState<DiffData | null>(null);
    const lastDiffRequestRef = React.useRef<string | null>(null);
    const sectionRef = React.useRef<HTMLDivElement | null>(null);

    const descriptor = React.useMemo(() => describeChange(file), [file]);
    const renderSideBySide = layout === 'side-by-side';

    const diffData = React.useMemo<DiffData | null>(() => {
        if (staged) return stagedDiffData;
        if (!cachedDiff) return localDiffData;
        return { original: cachedDiff.original, modified: cachedDiff.modified, isBinary: cachedDiff.isBinary };
    }, [cachedDiff, localDiffData, staged, stagedDiffData]);

    const setSectionRef = React.useCallback((node: HTMLDivElement | null) => {
        sectionRef.current = node;
        registerSectionRef(file.path, node);
    }, [file.path, registerSectionRef]);

    const handleOpenChange = React.useCallback((open: boolean) => {
        onExpandedChange(file.path, open);
    }, [file.path, onExpandedChange]);

    const handleSelect = React.useCallback(() => {
        onSelect(file.path);
    }, [file.path, onSelect]);

    React.useEffect(() => {
        if (!staged) {
            setLocalDiffData(null);
        } else {
            setStagedDiffData(null);
        }

        setDiffLoadError(null);
        lastDiffRequestRef.current = null;
    }, [staged, stagedRevision]);

    React.useEffect(() => {
        if (!isExpanded || !isMounted) return;
        if (!directory || diffData) {
            lastDiffRequestRef.current = null;
            setIsLoading(false);
            return;
        }

        const requestKey = `${directory}::${file.path}::${staged ? `staged:${stagedRevision}` : 'unstaged'}::${diffRetryNonce}`;
        if (lastDiffRequestRef.current === requestKey) {
            return;
        }
        lastDiffRequestRef.current = requestKey;
        setDiffLoadError(null);
        setIsLoading(true);

        let cancelled = false;
        const fetchPromise = isImageFile(file.path)
            ? git.getGitFileDiff(directory, { path: file.path, staged })
            : git.getGitDiff(directory, { path: file.path, staged, contextLines: FULL_CONTEXT_DIFF_LINES });
        const timeoutMs = DIFF_REQUEST_TIMEOUT_MS;
        const timeoutPromise = new Promise<never>((_, reject) => {
            setTimeout(() => reject(new Error(`Timed out after ${timeoutMs}ms`)), timeoutMs);
        });

        void Promise.race([fetchPromise, timeoutPromise])
            .then((response) => {
                if (cancelled) return;

                if ('diff' in response) {
                    const nextDiff = createTextDiffDataFromPatch(file.path, response.diff);
                    if (staged) {
                        setStagedDiffData(nextDiff);
                    } else {
                        setLocalDiffData(nextDiff);
                    }
                } else {
                    const nextDiff = {
                        original: response.original ?? '',
                        modified: response.modified ?? '',
                        isBinary: response.isBinary,
                    };
                    if (staged) {
                        setStagedDiffData(nextDiff);
                    } else {
                        setDiff(directory, file.path, nextDiff);
                    }
                }
                setIsLoading(false);
            })
            .catch((error) => {
                if (cancelled) return;
                const message = error instanceof Error ? error.message : String(error);
                setDiffLoadError(message);
                setIsLoading(false);
            });

        return () => {
            cancelled = true;
            if (lastDiffRequestRef.current === requestKey) {
                lastDiffRequestRef.current = null;
            }
        };
    }, [directory, diffData, diffRetryNonce, file.path, git, isExpanded, isMounted, setDiff, staged, stagedRevision]);

    const handleToggle = React.useCallback(() => {
        handleOpenChange(!isExpanded);
        handleSelect();
    }, [handleOpenChange, handleSelect, isExpanded]);

    return (
        <div ref={setSectionRef} className="scroll-mt-9 border-b border-[var(--interactive-border)]/40 last:border-b-0">
            <div className="sticky top-0 z-10 border-b border-[var(--interactive-border)]/35 bg-[var(--surface-elevated)]/90 backdrop-blur-md supports-[backdrop-filter]:bg-[var(--surface-elevated)]/80">
                <button
                    type="button"
                    onClick={handleToggle}
                    className={cn(
                        'group/header relative flex min-h-9 w-full items-center gap-2 overflow-hidden px-3 py-2',
                        'bg-transparent',
                        'text-muted-foreground hover:text-foreground',
                        isSelected ? 'bg-[var(--interactive-selection)]/35' : null
                    )}
                >
                    <div className="absolute inset-0 pointer-events-none group-hover/header:bg-[var(--interactive-hover)]/50" />
                    <div className="relative flex min-w-0 flex-1 items-center gap-2">
                        <span className="flex size-5 items-center justify-center opacity-70 group-hover/header:opacity-100">
                            {isExpanded ? (
                                <Icon name="arrow-down-s" className="size-4" />
                            ) : (
                                <Icon name="arrow-right-s" className="size-4" />
                            )}
                        </span>
                        <span
                            className="typography-micro font-semibold leading-none w-4 text-center uppercase"
                            style={{ color: descriptor.color }}
                            title={t(descriptor.descriptionKey)}
                            aria-label={t(descriptor.descriptionKey)}
                        >
                            {descriptor.code}
                        </span>
                        <span
                            className="min-w-0 flex-1 overflow-hidden typography-ui-label"
                            title={file.path}
                        >
                            <span className="flex min-w-0 items-center gap-2">
                                <FileTypeIcon filePath={file.path} className="h-3.5 w-3.5 flex-shrink-0 align-middle" />
                                {(() => {
                                    const lastSlash = file.path.lastIndexOf('/');
                                    if (lastSlash === -1) {
                                        return (
                                            <span
                                                className="block min-w-0 truncate typography-ui-label text-foreground"
                                                style={{ direction: 'rtl', textAlign: 'left', unicodeBidi: 'plaintext' }}
                                            >
                                                {file.path}
                                            </span>
                                        );
                                    }

                                    const dir = file.path.slice(0, lastSlash);
                                    const name = file.path.slice(lastSlash + 1);

                                    return (
                                        <span className="flex min-w-0 items-baseline overflow-hidden">
                                            <span
                                                className="min-w-0 truncate typography-ui-label text-muted-foreground"
                                                style={{ direction: 'rtl', textAlign: 'left', unicodeBidi: 'plaintext' }}
                                            >
                                                {dir}
                                            </span>
                                            <span className="flex-shrink-0 typography-ui-label">
                                                <span className="text-muted-foreground">/</span>
                                                <span className="text-foreground">{name}</span>
                                            </span>
                                        </span>
                                    );
                                })()}
                            </span>
                        </span>
                    </div>
                    <div className="relative flex items-center gap-2">
                        {formatDiffTotals(file.insertions, file.deletions)}
                        {showOpenInEditorAction && onOpenInEditor ? (
                            <Button
                                variant="ghost"
                                size="sm"
                                className="h-5 w-5 p-0 opacity-70 hover:opacity-100"
                                title={t('diffView.actions.openFileInEditorAtChange')}
                                onClick={(event) => {
                                    event.stopPropagation();
                                    onOpenInEditor(file.path, diffData);
                                }}
                                disabled={isOpeningInEditor}
                            >
                                {isOpeningInEditor ? (
                                    <Icon name="loader-4" className="size-3.5 animate-spin" />
                                ) : (
                                    <Icon name="edit" className="size-3.5" />
                                )}
                            </Button>
                        ) : null}
                        <DiffViewToggle
                            mode={renderSideBySide ? 'side-by-side' : 'unified'}
                            onModeChange={(mode: DiffViewMode) => {
                                const nextLayout: 'inline' | 'side-by-side' =
                                    mode === 'side-by-side' ? 'side-by-side' : 'inline';
                                setDiffFileLayout(file.path, nextLayout);
                            }}
                            className="opacity-70"
                        />
                    </div>
                </button>
            </div>
            {isExpanded && (
                <div className="relative bg-background overflow-hidden">
                    {!isMounted && !diffLoadError ? (
                        <div className="h-40 border border-border/40 bg-background/40" />
                    ) : null}
                    {diffLoadError ? (
                        <div className="flex flex-col items-center gap-2 px-4 py-8 text-sm text-muted-foreground">
                            <div className="typography-ui-label font-semibold text-foreground">
                                {t('diffView.state.failedToLoadDiff')}
                            </div>
                            <div className="typography-meta text-muted-foreground max-w-[32rem] text-center">
                                {diffLoadError}
                            </div>
                            <button
                                type="button"
                                className="typography-ui-label text-primary hover:underline"
                                onClick={() => setDiffRetryNonce((nonce) => nonce + 1)}
                            >
                                {t('diffView.actions.retry')}
                            </button>
                        </div>
                    ) : null}
                    {isMounted && isLoading && !diffData && !diffLoadError ? (
                        <div className="flex items-center justify-center gap-2 px-4 py-8 text-sm text-muted-foreground">
                            <Icon name="loader-4" className="size-4 animate-spin" />
                            {t('diffView.state.loadingDiff')}
                        </div>
                    ) : null}
                    {isMounted && diffData && !forceRenderLarge && (file.insertions + file.deletions) > LARGE_DIFF_CHANGED_LINES ? (
                        <div className="flex flex-col items-center gap-2 px-4 py-8 text-sm text-muted-foreground">
                            <div className="typography-ui-label font-semibold text-foreground">
                                {t('diffView.state.largeDiff', { count: file.insertions + file.deletions })}
                            </div>
                            <div className="typography-meta text-muted-foreground">
                                {t('diffView.state.largeDiffDescription')}
                            </div>
                            <button
                                type="button"
                                className="typography-ui-label text-primary hover:underline"
                                onClick={() => setForceRenderLarge(true)}
                            >
                                {t('diffView.actions.renderAnyway')}
                            </button>
                        </div>
                    ) : null}
                    {isMounted && diffData && (forceRenderLarge || (file.insertions + file.deletions) <= LARGE_DIFF_CHANGED_LINES) ? (
                        <InlineDiffViewer
                            filePath={file.path}
                            diff={diffData}
                            renderSideBySide={renderSideBySide}
                            wrapLines={wrapLines}
                        />
                    ) : null}
                </div>
            )}
        </div>
    );
});

interface DiffViewProps {
    hideStackedFileSidebar?: boolean;
    stackedDefaultCollapsedAll?: boolean;
    hideFileSelector?: boolean;
    pinSelectedFileHeaderToTopOnNavigate?: boolean;
    showOpenInEditorAction?: boolean;
    diffScope?: DiffScope;
    onDiffScopeChange?: (scope: Extract<DiffScope, 'working' | 'staged'>) => void;
    targetFilePath?: string | null;
    /** Render diff content flush with the container edges (no outer padding). */
    flushContent?: boolean;
}

export const DiffView: React.FC<DiffViewProps> = ({
    hideStackedFileSidebar = false,
    stackedDefaultCollapsedAll = false,
    hideFileSelector = false,
    pinSelectedFileHeaderToTopOnNavigate = false,
    showOpenInEditorAction = false,
    diffScope = 'all',
    onDiffScopeChange,
    targetFilePath = null,
    flushContent = false,
}) => {
    const { t } = useI18n();
    const { git, files } = useRuntimeAPIs();
    const effectiveDirectory = useEffectiveDirectory();
    const { screenWidth, isMobile } = useDeviceInfo();

    const isGitRepo = useIsGitRepo(effectiveDirectory ?? null);
    const status = useGitStatus(effectiveDirectory ?? null);
    const isLoadingStatus = useGitLoadingStatus(effectiveDirectory ?? null);
    const setActiveDirectory = useGitStore((state) => state.setActiveDirectory);
    const ensureStatus = useGitStore((state) => state.ensureStatus);
    const fetchStatus = useGitStore((state) => state.fetchStatus);
    const setDiff = useGitStore((state) => state.setDiff);
    const indexRevision = useGitStore(React.useCallback((state) => {
        if (!effectiveDirectory) return 0;
        return state.directories.get(effectiveDirectory)?.indexRevision ?? 0;
    }, [effectiveDirectory]));
	 
    const [selectedFile, setSelectedFile] = React.useState<string | null>(null);
    const [selectedFileStaged, setSelectedFileStaged] = React.useState(false);
    const [selectedStagedDiffData, setSelectedStagedDiffData] = React.useState<DiffData | null>(null);
    const [pinnedStackedTarget, setPinnedStackedTarget] = React.useState<string | null>(null);
    const [expandedFiles, setExpandedFiles] = React.useState<Set<string>>(() => new Set());
    const [mountedStackedFiles, setMountedStackedFiles] = React.useState<Set<string>>(() => new Set());

    const pendingDiffFile = useUIStore((state) => state.pendingDiffFile);
    const pendingDiffStaged = useUIStore((state) => state.pendingDiffStaged);
    const setPendingDiffFile = useUIStore((state) => state.setPendingDiffFile);
    const diffLayoutPreference = useUIStore((state) => state.diffLayoutPreference);
    const diffFileLayout = useUIStore((state) => state.diffFileLayout);
    const setDiffFileLayout = useUIStore((state) => state.setDiffFileLayout);
    const diffWrapLinesStore = useUIStore((state) => state.diffWrapLines);
    const setDiffWrapLines = useUIStore((state) => state.setDiffWrapLines);
    const openContextFileAtLine = useUIStore((state) => state.openContextFileAtLine);
    const diffWrapLines = diffWrapLinesStore;
    const forcedStaged = diffScope === 'staged' ? true : diffScope === 'working' ? false : null;
    const activeDiffStaged = forcedStaged ?? selectedFileStaged;

    const isMobileLayout = isMobile || screenWidth <= 768;
    const showFileSidebar = !hideStackedFileSidebar && !isMobileLayout && screenWidth >= 1024;
    const diffScrollRef = React.useRef<HTMLElement | null>(null);
    const fileSectionRefs = React.useRef(new Map<string, HTMLDivElement | null>());
    const pendingScrollTargetRef = React.useRef<string | null>(null);
    const pendingScrollFrameRef = React.useRef<number | null>(null);
    const shouldPinAfterAlignRef = React.useRef(false);
    const visibleSyncFrameRef = React.useRef<number | null>(null);

    const cancelPendingScrollAlignment = React.useCallback(() => {
        pendingScrollTargetRef.current = null;
        shouldPinAfterAlignRef.current = false;
        setPinnedStackedTarget(null);
        if (pendingScrollFrameRef.current !== null) {
            window.cancelAnimationFrame(pendingScrollFrameRef.current);
            pendingScrollFrameRef.current = null;
        }
    }, []);

    const expandStackedFile = React.useCallback((path: string) => {
        setExpandedFiles((previous) => {
            if (previous.has(path)) {
                return previous;
            }
            const next = new Set(previous);
            next.add(path);
            return next;
        });
    }, []);

    const changedFiles: FileEntry[] = React.useMemo(() => {
        if (!status?.files) return [];
        const diffStats = status.diffStats ?? {};
        const includeFile = diffScope === 'staged'
            ? isStagedStatusFile
            : diffScope === 'working'
                ? isWorkingStatusFile
                : () => true;

        return status.files
            .filter(includeFile)
            .map((file) => ({
                ...file,
                insertions: diffStats[file.path]?.insertions ?? 0,
                deletions: diffStats[file.path]?.deletions ?? 0,
                isNew: isNewStatusFile(file),
            }))
            .sort((a, b) => a.path.localeCompare(b.path));
    }, [diffScope, status]);

    const workingFileCount = React.useMemo(() => {
        if (!status?.files) return 0;
        return status.files.filter(isWorkingStatusFile).length;
    }, [status]);

    const stagedFileCount = React.useMemo(() => {
        if (!status?.files) return 0;
        return status.files.filter(isStagedStatusFile).length;
    }, [status]);

    const selectedFileEntry = React.useMemo(() => {
        if (!selectedFile) return null;
        return changedFiles.find((file) => file.path === selectedFile) ?? null;
    }, [changedFiles, selectedFile]);

    const changedFilePathsKey = React.useMemo(
        () => changedFiles.map((file) => file.path).join('\0'),
        [changedFiles],
    );

    React.useEffect(() => {
        const paths = changedFilePathsKey ? changedFilePathsKey.split('\0') : [];
        const defaultExpandedCount = stackedDefaultCollapsedAll
            ? 0
            : getStackedViewDefaultExpandedCount(paths.length);
        const defaultExpanded = new Set(paths.slice(0, defaultExpandedCount));
        setExpandedFiles(defaultExpanded);
        setMountedStackedFiles(new Set());
    }, [changedFilePathsKey, stackedDefaultCollapsedAll]);

    const syncVisibleStackedFiles = React.useCallback(() => {
        visibleSyncFrameRef.current = null;
        const scrollRoot = diffScrollRef.current;
        if (!scrollRoot) return;

        const rootRect = scrollRoot.getBoundingClientRect();
        const top = rootRect.top - STACKED_DIFF_MOUNT_MARGIN;
        const bottom = rootRect.bottom + STACKED_DIFF_MOUNT_MARGIN;
        const next: Record<string, boolean> = {};

        for (const [path, node] of fileSectionRefs.current) {
            if (!node || !expandedFiles.has(path)) continue;
            const rect = node.getBoundingClientRect();
            if (rect.bottom < top || rect.top > bottom) continue;
            next[path] = true;
        }

        setMountedStackedFiles((previous) => {
            let changed = false;
            const mounted = new Set(previous);
            for (const path of Object.keys(next)) {
                if (mounted.has(path)) continue;
                mounted.add(path);
                changed = true;
            }
            return changed ? mounted : previous;
        });
    }, [expandedFiles]);

    const queueVisibleStackedFilesSync = React.useCallback(() => {
        if (typeof window === 'undefined') return;
        if (visibleSyncFrameRef.current !== null) return;
        visibleSyncFrameRef.current = window.requestAnimationFrame(syncVisibleStackedFiles);
    }, [syncVisibleStackedFiles]);

    React.useEffect(() => {
        const scrollRoot = diffScrollRef.current;
        if (!scrollRoot) return;

        queueVisibleStackedFilesSync();
        scrollRoot.addEventListener('scroll', queueVisibleStackedFilesSync, { passive: true });
        window.addEventListener('resize', queueVisibleStackedFilesSync);

        return () => {
            scrollRoot.removeEventListener('scroll', queueVisibleStackedFilesSync);
            window.removeEventListener('resize', queueVisibleStackedFilesSync);
            if (visibleSyncFrameRef.current !== null) {
                window.cancelAnimationFrame(visibleSyncFrameRef.current);
                visibleSyncFrameRef.current = null;
            }
        };
    }, [changedFiles, expandedFiles, queueVisibleStackedFilesSync]);

    const getLayoutForFile = React.useCallback((file: FileEntry): 'inline' | 'side-by-side' => {
        const override = diffFileLayout[file.path];
        if (override) return override;

        if (diffLayoutPreference === 'inline') {
            return 'inline';
        }

        if (diffLayoutPreference === 'side-by-side') {
            return 'side-by-side';
        }

        const isNarrow = screenWidth < SIDE_BY_SIDE_MIN_WIDTH;
        if (file.isNew || isNarrow) {
            return 'inline';
        }

        return 'side-by-side';
    }, [diffFileLayout, diffLayoutPreference, screenWidth]);

    const currentLayoutForSelectedFile = React.useMemo<'inline' | 'side-by-side' | null>(() => {
        if (!selectedFileEntry) return null;
        return getLayoutForFile(selectedFileEntry);
    }, [getLayoutForFile, selectedFileEntry]);

    // Ensure git status on mount
    React.useEffect(() => {
        if (effectiveDirectory) {
            setActiveDirectory(effectiveDirectory);
            void ensureStatus(effectiveDirectory, git);
        }
    }, [effectiveDirectory, setActiveDirectory, ensureStatus, git]);

    React.useEffect(() => {
        if (!effectiveDirectory) {
            return;
        }

        return sessionEvents.onGitRefreshHint((hint) => {
            if (normalizePath(hint.directory) !== normalizePath(effectiveDirectory)) {
                return;
            }
            void fetchStatus(effectiveDirectory, git);
        });
    }, [effectiveDirectory, fetchStatus, git]);

    // Handle pending diff file from external navigation
    React.useEffect(() => {
        if (diffScope !== 'all') {
            return;
        }

        if (pendingDiffFile) {
            setSelectedFile(pendingDiffFile);
            setSelectedFileStaged(pendingDiffStaged);
            setSelectedStagedDiffData(null);
            setPendingDiffFile(null);
            shouldPinAfterAlignRef.current = true;
            pendingScrollTargetRef.current = pendingDiffFile;
            expandStackedFile(pendingDiffFile);
        }
    }, [diffScope, expandStackedFile, pendingDiffFile, pendingDiffStaged, setPendingDiffFile]);

    React.useEffect(() => {
        if (diffScope === 'all') {
            return;
        }

        const normalizedTarget = targetFilePath?.trim();
        if (!normalizedTarget) {
            return;
        }

        setSelectedFile(normalizedTarget);
        setSelectedFileStaged(diffScope === 'staged');
        setSelectedStagedDiffData(null);

        shouldPinAfterAlignRef.current = true;
        pendingScrollTargetRef.current = normalizedTarget;
        expandStackedFile(normalizedTarget);
    }, [diffScope, expandStackedFile, targetFilePath]);

    React.useEffect(() => {
        if (!activeDiffStaged) {
            return;
        }

        setSelectedStagedDiffData(null);
    }, [activeDiffStaged, indexRevision]);

    // Auto-select first file (skip if we have a pending file to consume)
    React.useEffect(() => {
        if (!selectedFile && !pendingDiffFile && changedFiles.length > 0) {
            setSelectedFile(changedFiles[0].path);
        }
    }, [changedFiles, selectedFile, pendingDiffFile]);

    // Clear selection if file no longer exists
    React.useEffect(() => {
        if (selectedFile && changedFiles.length > 0) {
            const stillExists = changedFiles.some((f) => f.path === selectedFile);
            if (!stillExists) {
                setSelectedFile(changedFiles[0]?.path ?? null);
            }
        }
    }, [changedFiles, selectedFile]);

    const registerSectionRef = React.useCallback((path: string, node: HTMLDivElement | null) => {
        const map = fileSectionRefs.current;
        if (node) {
            map.set(path, node);
        } else {
            map.delete(path);
        }
        queueVisibleStackedFilesSync();
    }, [queueVisibleStackedFilesSync]);

    const handleStackedEntryExpandedChange = React.useCallback((path: string, expanded: boolean) => {
        cancelPendingScrollAlignment();
        setExpandedFiles((previous) => {
            const hasPath = previous.has(path);
            if (expanded === hasPath) {
                return previous;
            }
            const next = new Set(previous);
            if (expanded) {
                next.add(path);
            } else {
                next.delete(path);
            }
            return next;
        });
        if (!expanded) {
            setMountedStackedFiles((previous) => {
                if (!previous.has(path)) return previous;
                const next = new Set(previous);
                next.delete(path);
                return next;
            });
        }
        queueVisibleStackedFilesSync();
    }, [cancelPendingScrollAlignment, queueVisibleStackedFilesSync]);

    const handleExpandOrCollapseAll = React.useCallback(() => {
        cancelPendingScrollAlignment();
        setExpandedFiles((previous) => {
            if (previous.size > 0) {
                return new Set();
            }
            return new Set(changedFiles.map((file) => file.path));
        });
        setMountedStackedFiles(new Set());
        queueVisibleStackedFilesSync();
    }, [cancelPendingScrollAlignment, changedFiles, queueVisibleStackedFilesSync]);

    const scrollToFile = React.useCallback((path: string): boolean => {
        const node = fileSectionRefs.current.get(path);
        const scrollRoot = diffScrollRef.current;
        if (!node || !scrollRoot) {
            return false;
        }

        const rootRect = scrollRoot.getBoundingClientRect();
        const nodeRect = node.getBoundingClientRect();
        const delta = nodeRect.top - rootRect.top;
        const maxTop = Math.max(0, scrollRoot.scrollHeight - scrollRoot.clientHeight);
        scrollRoot.scrollTop = Math.min(maxTop, Math.max(0, scrollRoot.scrollTop + delta));
        return true;
    }, []);

    React.useEffect(() => {
        const target = pendingScrollTargetRef.current;
        if (!target) return;

        let attempts = 0;
        const maxAttempts = 20;
        let cancelled = false;

        const cancelPending = () => {
            if (cancelled) {
                return;
            }
            cancelled = true;
            pendingScrollTargetRef.current = null;
            shouldPinAfterAlignRef.current = false;
            setPinnedStackedTarget(null);
            if (pendingScrollFrameRef.current !== null) {
                window.cancelAnimationFrame(pendingScrollFrameRef.current);
                pendingScrollFrameRef.current = null;
            }
        };

        const tryAlign = () => {
            if (cancelled) {
                pendingScrollFrameRef.current = null;
                return;
            }
            const currentTarget = pendingScrollTargetRef.current;
            if (!currentTarget) {
                cancelPending();
                pendingScrollFrameRef.current = null;
                return;
            }

            const result = scrollToFile(currentTarget);
            if (!result) {
                attempts += 1;
                if (attempts < maxAttempts) {
                    pendingScrollFrameRef.current = window.requestAnimationFrame(tryAlign);
                } else {
                    cancelPending();
                    pendingScrollFrameRef.current = null;
                }
                return;
            }

            if (pinSelectedFileHeaderToTopOnNavigate && shouldPinAfterAlignRef.current) {
                setPinnedStackedTarget(currentTarget);
            }
            cancelPending();
        };

        pendingScrollFrameRef.current = window.requestAnimationFrame(tryAlign);

        return () => {
            cancelled = true;
            if (pendingScrollFrameRef.current !== null) {
                window.cancelAnimationFrame(pendingScrollFrameRef.current);
                pendingScrollFrameRef.current = null;
            }
        };
    }, [pinSelectedFileHeaderToTopOnNavigate, scrollToFile, selectedFile]);

    const handleSelectFile = React.useCallback((value: string) => {
        setSelectedFile(value);
        setSelectedFileStaged(false);
        setSelectedStagedDiffData(null);
    }, []);

    const handleSelectFileAndScroll = React.useCallback((value: string) => {
        cancelPendingScrollAlignment();

        setSelectedFile(value);
        setSelectedFileStaged(false);
        setSelectedStagedDiffData(null);

        shouldPinAfterAlignRef.current = true;
        pendingScrollTargetRef.current = value;
        expandStackedFile(value);
        scrollToFile(value);
    }, [cancelPendingScrollAlignment, expandStackedFile, scrollToFile]);

    const handleHeaderLayoutChange = React.useCallback((mode: DiffViewMode) => {
        const nextLayout: 'inline' | 'side-by-side' =
            mode === 'side-by-side' ? 'side-by-side' : 'inline';

        changedFiles.forEach((file) => {
            setDiffFileLayout(file.path, nextLayout);
        });
    }, [changedFiles, setDiffFileLayout]);

    const showFileSelector = !hideFileSelector && !showFileSidebar;

    const selectedCachedDiff = useGitStore(React.useCallback((state) => {
        if (!effectiveDirectory || !selectedFile || activeDiffStaged) return null;
        return state.directories.get(effectiveDirectory)?.diffCache.get(selectedFile) ?? null;
    }, [activeDiffStaged, effectiveDirectory, selectedFile]));

    const selectedDiffData = React.useMemo<DiffData | null>(() => {
        if (activeDiffStaged) return selectedStagedDiffData;
        if (!selectedCachedDiff) return null;
        return { original: selectedCachedDiff.original, modified: selectedCachedDiff.modified, isBinary: selectedCachedDiff.isBinary };
    }, [activeDiffStaged, selectedCachedDiff, selectedStagedDiffData]);

    const [openingEditorFilePath, setOpeningEditorFilePath] = React.useState<string | null>(null);

    const openFileInEditorAtChange = React.useCallback(async (filePath: string, cachedDiffData: DiffData | null) => {
        if (!effectiveDirectory || !filePath) {
            return;
        }

        setOpeningEditorFilePath(filePath);
        try {
            let targetLine: number | null = null;

            if (cachedDiffData && !cachedDiffData.isBinary && !isImageFile(filePath)) {
                targetLine = getFirstChangedModifiedLine(cachedDiffData.original, cachedDiffData.modified);
            }

            if (targetLine === null) {
                try {
                    const patchResponse = await git.getGitDiff(effectiveDirectory, {
                        path: filePath,
                        staged: activeDiffStaged,
                        contextLines: 3,
                    });
                    targetLine = getFirstVisibleModifiedLineFromPatch(patchResponse.diff);
                } catch {
                    targetLine = null;
                }
            }

            let diffForNavigation = cachedDiffData;
            if (targetLine === null || !diffForNavigation) {
                const response = await git.getGitFileDiff(effectiveDirectory, { path: filePath, staged: activeDiffStaged });
                diffForNavigation = {
                    original: response.original ?? '',
                    modified: response.modified ?? '',
                    isBinary: response.isBinary,
                };
                if (!activeDiffStaged) {
                    setDiff(effectiveDirectory, filePath, diffForNavigation);
                }
            }

            const resolvedTargetLine = targetLine ?? ((diffForNavigation.isBinary || isImageFile(filePath))
                ? 1
                : getFirstChangedModifiedLine(diffForNavigation.original, diffForNavigation.modified));

            const absolutePath = toAbsolutePath(effectiveDirectory, filePath);
            const openValidation = await validateContextFileOpen(files, absolutePath);
            if (!openValidation.ok) {
                toast.error(getContextFileOpenFailureMessage(openValidation.reason));
                return;
            }

            openContextFileAtLine(
                effectiveDirectory,
                absolutePath,
                resolvedTargetLine,
                1,
            );
        } finally {
            setOpeningEditorFilePath((current) => (current === filePath ? null : current));
        }
    }, [activeDiffStaged, effectiveDirectory, files, git, openContextFileAtLine, setDiff]);

    const openSelectedFileInEditorAtChange = React.useCallback(async () => {
        if (!selectedFile) {
            return;
        }

        await openFileInEditorAtChange(selectedFile, selectedDiffData);
    }, [openFileInEditorAtChange, selectedDiffData, selectedFile]);

    const isOpeningSelectedInEditor = Boolean(selectedFile && openingEditorFilePath === selectedFile);

    const renderStackedDiffView = () => {
        if (!effectiveDirectory) return null;

        const getFileStaged = (path: string) => {
            if (forcedStaged !== null) {
                return forcedStaged;
            }
            return selectedFileStaged && path === selectedFile;
        };

        return (
            <div className={cn('flex flex-1 min-h-0 h-full', flushContent ? 'gap-0' : 'gap-3 px-3 pb-3 pt-2')}>
                {showFileSidebar && (
                    <section className="hidden lg:flex w-72 flex-col rounded-xl border border-border/60 bg-background/70 overflow-hidden">
                        <div className="flex items-center justify-between px-3 py-1.5 border-b border-border/40">
                            <span className="typography-ui-header font-semibold text-foreground">{t('diffView.section.files')}</span>
                            <span className="typography-meta text-muted-foreground">{changedFiles.length}</span>
                        </div>
                        <FileList
                            changedFiles={changedFiles}
                            selectedFile={selectedFile}
                            onSelectFile={handleSelectFileAndScroll}
                        />
                    </section>
                )}
                <ScrollableOverlay
                    ref={diffScrollRef}
                    outerClassName="flex-1 min-h-0 h-full"
                    className="[overflow-anchor:none]"
                    disableHorizontal
                    observeMutations={false}
                    preventOverscroll
                    data-diff-virtual-root
                >
                    <div className="flex flex-col [overflow-anchor:none]" data-diff-virtual-content>
                        {changedFiles.map((file) => (
                            <MultiFileDiffEntry
                                key={`${getFileStaged(file.path) ? 'staged' : 'unstaged'}:${file.path}`}
                                directory={effectiveDirectory}
                                file={file}
                                layout={getLayoutForFile(file)}
                                wrapLines={diffWrapLines}
                                isSelected={file.path === selectedFile}
                                isExpanded={expandedFiles.has(file.path)}
                                isMounted={mountedStackedFiles.has(file.path) || file.path === selectedFile || file.path === pinnedStackedTarget}
                                onSelect={handleSelectFile}
                                onExpandedChange={handleStackedEntryExpandedChange}
                                registerSectionRef={registerSectionRef}
                                showOpenInEditorAction={showOpenInEditorAction}
                                isOpeningInEditor={openingEditorFilePath === file.path}
                                onOpenInEditor={(filePath, diffData) => {
                                    void openFileInEditorAtChange(filePath, diffData);
                                }}
                                staged={getFileStaged(file.path)}
                                stagedRevision={indexRevision}
                            />
                        ))}
                    </div>
                </ScrollableOverlay>
            </div>
        );
    };

    const renderContent = () => {

        if (!effectiveDirectory) {
            return (
                <div className="flex flex-1 items-center justify-center text-sm text-muted-foreground">
                    {t('diffView.state.selectSessionDirectory')}
                </div>
            );
        }

        if (isLoadingStatus && !status) {
            return (
                <div className="flex flex-1 items-center justify-center gap-2 text-sm text-muted-foreground">
                    <Icon name="loader-4" className="size-4 animate-spin" />
                    {t('diffView.state.loadingRepositoryStatus')}
                </div>
            );
        }

        if (isGitRepo === false) {
            return (
                <div className="flex flex-1 items-center justify-center text-sm text-muted-foreground">
                    {t('diffView.state.notGitRepository')}
                </div>
            );
        }

        if (changedFiles.length === 0) {
            return (
                <div className="flex flex-1 items-center justify-center text-sm text-muted-foreground">
                    {t('diffView.state.cleanWorkingTree')}
                </div>
            );
        }

        return renderStackedDiffView();
    };

    return (
        <div className="flex h-full flex-col overflow-hidden bg-background">
            <div className="@container/diff-toolbar flex min-w-0 items-center gap-2 px-3 py-2 bg-background">
                {!isMobile && (
                    diffScope === 'working' || diffScope === 'staged' ? (
                        <ChangeScopeSelector
                            scope={diffScope}
                            workingCount={workingFileCount}
                            stagedCount={stagedFileCount}
                            onScopeChange={onDiffScopeChange}
                        />
                    ) : (
                        <div className="flex items-center gap-1 rounded-md px-2 py-1 text-muted-foreground shrink-0">
                            <span className="typography-ui-label font-semibold text-foreground">
                                {isLoadingStatus && !status
                                    ? t('diffView.state.loadingChanges')
                                    : (changedFiles.length === 1
                                        ? t('diffView.summary.changedFilesSingle', { count: changedFiles.length })
                                        : t('diffView.summary.changedFilesPlural', { count: changedFiles.length }))}
                            </span>
                        </div>
                    )
                )}
                {showFileSelector && (
                    <FileSelector
                        changedFiles={changedFiles}
                        selectedFile={selectedFile}
                        selectedFileEntry={selectedFileEntry}
                        onSelectFile={handleSelectFileAndScroll}
                        className="w-fit min-w-0"
                    />
                )}
                {!showFileSelector ? <div className="min-w-0 flex-1" /> : null}
                {changedFiles.length > 0 && (
                    <Button
                        variant="ghost"
                        size="sm"
                        onClick={handleExpandOrCollapseAll}
                        className={cn(
                            'diff-toolbar__expand-button h-7 flex-shrink-0 gap-1 px-1.5 text-muted-foreground hover:text-foreground',
                            showFileSelector && 'ml-auto',
                        )}
                        title={expandedFiles.size > 0 ? t('diffView.actions.collapseAll') : t('diffView.actions.expandAll')}
                    >
                        <Icon
                            name="expand-up-down"
                            className="size-4"
                        />
                        <span className="diff-toolbar__expand-label typography-ui-label">
                            {expandedFiles.size > 0 ? t('diffView.actions.collapseAll') : t('diffView.actions.expandAll')}
                        </span>
                    </Button>
                )}
                {selectedFileEntry && (
                    <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => setDiffWrapLines(!diffWrapLinesStore)}
                        className={cn(
                            'h-5 w-5 p-0 transition-opacity',
                            diffWrapLines ? 'text-foreground opacity-100' : 'text-muted-foreground opacity-60 hover:opacity-100'
                        )}
                        title={diffWrapLines ? t('diffView.actions.disableLineWrap') : t('diffView.actions.enableLineWrap')}
                    >
                        <Icon name="text-wrap" className="size-4" />
                    </Button>
                )}
                {showOpenInEditorAction && selectedFileEntry && (
                    <Button
                        variant="ghost"
                        size="sm"
                        className="h-5 w-5 p-0 opacity-70 hover:opacity-100"
                        onClick={() => {
                            void openSelectedFileInEditorAtChange();
                        }}
                        disabled={isOpeningSelectedInEditor}
                        title={t('diffView.actions.openFileAtFirstChangedLine')}
                    >
                        {isOpeningSelectedInEditor ? (
                            <Icon name="loader-4" className="size-3.5 animate-spin" />
                        ) : (
                            <Icon name="edit" className="size-3.5" />
                        )}
                    </Button>
                )}
                {selectedFileEntry && currentLayoutForSelectedFile && (
                    <DiffViewToggle
                        mode={currentLayoutForSelectedFile === 'side-by-side' ? 'side-by-side' : 'unified'}
                        onModeChange={handleHeaderLayoutChange}
                    />
                )}
            </div>

            {renderContent()}
        </div>
    );
};

// eslint-disable-next-line react-refresh/only-export-components
export const useDiffFileCount = (): number => {
    const { git } = useRuntimeAPIs();
    const effectiveDirectory = useEffectiveDirectory();

    const setActiveDirectory = useGitStore((state) => state.setActiveDirectory);
    const ensureStatus = useGitStore((state) => state.ensureStatus);
    const fileCount = useGitFileCount(effectiveDirectory ?? null);

    React.useEffect(() => {
        if (effectiveDirectory) {
            setActiveDirectory(effectiveDirectory);
            void ensureStatus(effectiveDirectory, git);
        }
    }, [effectiveDirectory, setActiveDirectory, ensureStatus, git]);

    return fileCount;
};
