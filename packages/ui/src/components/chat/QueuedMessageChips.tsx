import React, { memo } from 'react';
import {
    DndContext,
    MouseSensor,
    TouchSensor,
    useSensor,
    useSensors,
    closestCenter,
    type DragEndEvent,
} from '@dnd-kit/core';
import {
    SortableContext,
    useSortable,
    verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { useEvent } from '@reactuses/core';
import { getQueueForScope, legacyQueueScope, queueScopeKey, useMessageQueueStore, type QueueItem, type QueueScope, type QueuedMessage } from '@/stores/messageQueueStore';
import { useSessionUIStore } from '@/sync/session-ui-store';
import { useInputStore } from '@/sync/input-store';
import type { DraftKey } from '@/sync/input-draft-types';
import { useMessageQueueServerScope } from '@/sync/use-message-queue-server';
import type { MessageQueueItem } from '@/lib/message-queue-server';
import { useI18n } from '@/lib/i18n';
import { getRuntimeTransportIdentity, subscribeRuntimeEndpointChanged } from '@/lib/runtime-switch';
import { useEffectiveDirectory } from '@/hooks/useEffectiveDirectory';
import { useQueueScopeDispatchFlight } from '@/hooks/useQueuedMessageAutoSend';
import { useUIStore } from '@/stores/useUIStore';
import { Icon } from "@/components/icon/Icon";
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { createUuid } from '@/lib/uuid';
import { toast } from '@/components/ui';
import { canSendQueuedMessage, canSendServerQueuedMessage, mergeQueuedMessageScopes, popQueuedMessageForEdit, queueModeAllowsMutations, reorderServerQueueItems, serverQueueEditInput, serverQueueItemMutationInput } from './queuedMessageChipsState';

type BoundQueueScope = Extract<QueueScope, { state: 'bound' }>;

interface QueuedMessageChipProps {
    message: QueuedMessage | MessageQueueItem;
    server: boolean;
    frozen: boolean;
    hasDispatchLock: boolean;
    isMobile: boolean;
    onEdit: (message: QueuedMessage | MessageQueueItem) => void;
    onSend: (message: QueuedMessage | MessageQueueItem) => void;
    onRemove: (message: QueuedMessage | MessageQueueItem) => void;
}

const QueuedMessageChip = memo(({ message, server, frozen, hasDispatchLock, isMobile, onEdit, onSend, onRemove }: QueuedMessageChipProps) => {
    const { t } = useI18n();
    const status = message.status ?? 'queued';
    const isReadOnly = frozen || status === 'sending' || status === 'reconciling';
    const legacyMessage = server ? undefined : message as QueuedMessage;
    const isDragDisabled = legacyMessage?.owner?.state === 'unbound-legacy' || isReadOnly;
    const canSend = !frozen && (server ? canSendServerQueuedMessage(message as MessageQueueItem, hasDispatchLock) : canSendQueuedMessage(message as QueuedMessage, hasDispatchLock));
    const queueItemID = message.queueItemID || (message as QueuedMessage).id;
    const recovery = legacyMessage?.failure?.recovery;
    const visibleContent = recovery?.content ?? message.content;
    const visibleAttachments = recovery?.attachments ?? message.attachments;
    const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
        id: queueItemID,
        disabled: isDragDisabled,
    });

    // Get first line of message, truncated
    const firstLine = React.useMemo(() => {
        const lines = visibleContent.split('\n');
        const first = lines[0] || '';
        const maxLength = 100;
        if (first.length > maxLength) {
            return first.substring(0, maxLength) + '...';
        }
        return first + (lines.length > 1 ? '...' : '');
    }, [visibleContent]);

    const attachmentCount = visibleAttachments?.length ?? 0;

    return (
        <div
            ref={setNodeRef}
            // Translate only (no scaleX/scaleY) so the lifted row keeps its size.
            style={{ transform: CSS.Translate.toString(transform), transition }}
            className={cn(
                'flex min-w-0 items-center',
                isMobile
                    ? 'gap-0.5 py-1'
                    : 'flex gap-1.5 py-0.5 md:gap-2 md:py-1',
                isDragging && 'z-10 opacity-60',
            )}
        >
            <button
                type="button"
                {...attributes}
                {...listeners}
                disabled={isDragDisabled}
                className={cn(
                    'flex flex-shrink-0 touch-none select-none items-center justify-center text-muted-foreground',
                    isMobile ? '!h-6 !w-4 !min-h-6 !min-w-4' : 'size-auto',
                    isDragDisabled ? 'cursor-default opacity-50' : 'cursor-grab hover:text-foreground active:cursor-grabbing',
                )}
                aria-label={t('chat.queuedMessage.reorderAria')}
            >
                <Icon name="draggable" className={cn(isMobile ? 'size-3' : 'size-3.5 md:size-4')} aria-hidden="true" />
            </button>
            {isMobile ? (
                <>
                    <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="-ml-0.5 !h-6 !w-4 !min-h-6 !min-w-4 rounded-md bg-transparent text-muted-foreground hover:bg-transparent hover:text-foreground active:bg-transparent"
                        onClick={() => onRemove(message)}
                        disabled={isReadOnly}
                        aria-label={t('chat.queuedMessage.removeAria')}
                    >
                        <Icon name="close" className="size-3" aria-hidden="true" />
                    </Button>
                    <span className="min-w-0 flex-1 truncate text-xs leading-4 text-foreground">
                        {firstLine || t('chat.queuedMessage.empty')}
                        {attachmentCount > 0 && (
                            <span className="ml-1 text-muted-foreground">{t('chat.queuedMessage.attachments', { count: attachmentCount })}</span>
                        )}
                    </span>
                    <div className="flex flex-shrink-0 items-center gap-1">
                        <Button
                            type="button"
                            variant="secondary"
                            size="xs"
                            className="!h-6 !min-h-6 !min-w-6 gap-0.5 px-1 !text-xs leading-4 min-[360px]:px-1.5"
                            onClick={() => onEdit(message)}
                            disabled={isReadOnly}
                            aria-label={t('chat.queuedMessage.edit')}
                        >
                            <Icon name="edit" className="size-3" aria-hidden="true" />
                            <span className="hidden max-w-16 truncate min-[360px]:inline">{t('chat.queuedMessage.edit')}</span>
                        </Button>
                        <Button
                            type="button"
                            variant="secondary"
                            size="xs"
                            className="!h-6 !min-h-6 !min-w-6 gap-0.5 px-1 !text-xs leading-4 min-[360px]:px-1.5"
                            onClick={() => onSend(message)}
                            disabled={!canSend}
                            aria-label={t('chat.queuedMessage.send')}
                        >
                            <Icon name="send-plane" className="size-3" aria-hidden="true" />
                            <span className="hidden max-w-16 truncate min-[360px]:inline">{t('chat.queuedMessage.send')}</span>
                        </Button>
                    </div>
                </>
            ) : (
                <>
                    <span className="min-w-0 flex-1 truncate typography-micro leading-4 text-foreground md:typography-ui-label">
                        {firstLine || t('chat.queuedMessage.empty')}
                        {attachmentCount > 0 && (
                            <span className="ml-1 text-muted-foreground">{t('chat.queuedMessage.attachments', { count: attachmentCount })}</span>
                        )}
                    </span>
                    <div className="flex flex-shrink-0 items-center gap-1.5">
                        <Button
                            type="button"
                            variant="secondary"
                            size="xs"
                            onClick={() => onEdit(message)}
                            disabled={isReadOnly}
                        >
                            <Icon name="edit" className="size-3" aria-hidden="true" />
                            {t('chat.queuedMessage.edit')}
                        </Button>
                        <Button
                            type="button"
                            variant="secondary"
                            size="xs"
                            onClick={() => onSend(message)}
                            disabled={!canSend}
                        >
                            <Icon name="send-plane" className="size-3" aria-hidden="true" />
                            {t('chat.queuedMessage.send')}
                        </Button>
                        <button
                            type="button"
                            onClick={() => onRemove(message)}
                            disabled={isReadOnly}
                            className={cn(
                                'flex flex-shrink-0 items-center justify-center text-muted-foreground transition-colors',
                                'hover:bg-[var(--interactive-hover)] hover:text-foreground',
                                'disabled:pointer-events-none disabled:opacity-50',
                                'size-6 rounded-full',
                            )}
                            aria-label={t('chat.queuedMessage.removeAria')}
                        >
                            <Icon name="close" className="size-3.5" aria-hidden="true" />
                        </button>
                    </div>
                </>
            )}
        </div>
    );
});

QueuedMessageChip.displayName = 'QueuedMessageChip';

interface QueuedMessageChipsProps {
    onEditMessage: (content: string, attachments?: QueuedMessage['attachments'], composerDocument?: QueuedMessage['composerDocument'], composerMentions?: QueuedMessage['composerMentions']) => void;
    onSendMessage: (messageId: string) => void;
    draftKey: DraftKey | null;
}

const EMPTY_QUEUE: QueueItem[] = [];
const subscribeRuntimeTransport = (notify: () => void) => subscribeRuntimeEndpointChanged(() => notify());

export const QueuedMessageChips = memo(({ onEditMessage, onSendMessage, draftKey }: QueuedMessageChipsProps) => {
    const { t } = useI18n();
    const isMobile = useUIStore((state) => state.isMobile);
    const currentSessionId = useSessionUIStore((state) => state.currentSessionId);
    const fallbackDirectory = useEffectiveDirectory();
    const currentSessionDirectorySelector = React.useMemo(
        () => (state: ReturnType<typeof useSessionUIStore.getState>) => currentSessionId ? state.getDirectoryForSession(currentSessionId) : null,
        [currentSessionId],
    );
    const currentSessionDirectory = useSessionUIStore(currentSessionDirectorySelector);
    const transportIdentity = React.useSyncExternalStore(
        subscribeRuntimeTransport,
        getRuntimeTransportIdentity,
        getRuntimeTransportIdentity,
    );
    const queueScope = React.useMemo<BoundQueueScope | null>(() => {
        const directory = currentSessionDirectory || fallbackDirectory;
        if (!currentSessionId || !directory) return null;
        return {
            state: 'bound',
            transportIdentity,
            directory,
            sessionID: currentSessionId,
        };
    }, [currentSessionDirectory, currentSessionId, fallbackDirectory, transportIdentity]);
    const serverQueue = useMessageQueueServerScope({
        transportIdentity,
        directory: queueScope?.directory ?? '',
        sessionID: queueScope?.sessionID ?? '',
    });
    const legacyScope = React.useMemo(() => currentSessionId ? legacyQueueScope(currentSessionId) : null, [currentSessionId]);
    const boundQueueSelector = React.useMemo(
        () => (state: ReturnType<typeof useMessageQueueStore.getState>) => queueScope ? getQueueForScope(state, queueScope) : EMPTY_QUEUE,
        [queueScope],
    );
    const boundQueuedMessages = useMessageQueueStore(boundQueueSelector);
    const legacyQueueSelector = React.useMemo(
        () => (state: ReturnType<typeof useMessageQueueStore.getState>) => legacyScope ? getQueueForScope(state, legacyScope) : EMPTY_QUEUE,
        [legacyScope],
    );
    const legacyQueuedMessages = useMessageQueueStore(legacyQueueSelector);
    const legacyMessages = React.useMemo(
        () => mergeQueuedMessageScopes(legacyQueuedMessages, boundQueuedMessages),
        [boundQueuedMessages, legacyQueuedMessages],
    );
    const queuedMessages = serverQueue.mode === 'server' ? serverQueue.items : legacyMessages;
    const frozen = !queueModeAllowsMutations(serverQueue.mode);
    const hasScopeDispatchFlight = useQueueScopeDispatchFlight(queueScope);
    const hasDispatchLock = React.useMemo(
        () => hasScopeDispatchFlight || queuedMessages.some((item) => item.status === 'sending' || item.status === 'reconciling'),
        [hasScopeDispatchFlight, queuedMessages],
    );
    const popToInput = useMessageQueueStore((state) => state.popToInput);
    const reorderQueue = useMessageQueueStore((state) => state.reorderQueue);

    const sensors = useSensors(
        // Desktop: drag after a small move so other clicks still register.
        useSensor(MouseSensor, { activationConstraint: { distance: 8 } }),
        // Touch: long-press to drag (tap still hits buttons, swipe scrolls).
        useSensor(TouchSensor, { activationConstraint: { delay: 200, tolerance: 6 } }),
    );

    const handleDragEnd = useEvent((event: DragEndEvent) => {
        if (frozen) return;
        const { active, over } = event;
        if (!over || active.id === over.id) return;
        if (serverQueue.mode === 'server') {
            if (!serverQueue.scope) return;
            const input = reorderServerQueueItems(serverQueue.scope, String(active.id), String(over.id), createUuid());
            if (input) void serverQueue.actions.reorder(input).catch(() => toast.error(t('chat.chatInput.toast.messageSendFailed')));
            return;
        }
        const legacyQueueMessages = queuedMessages as QueuedMessage[];
        const activeMessage = legacyQueueMessages.find((message) => (message.queueItemID ?? message.id) === active.id);
        const overMessage = legacyQueueMessages.find((message) => (message.queueItemID ?? message.id) === over.id);
        if (!activeMessage || !overMessage) return;
        const activeScope = activeMessage.owner;
        const overScope = overMessage.owner;
        if (activeScope?.state !== 'bound' || overScope?.state !== 'bound' || queueScopeKey(activeScope) !== queueScopeKey(overScope)) return;
        reorderQueue(activeScope, String(active.id), String(over.id), activeMessage.operationID);
    });

    const handleEdit = useEvent((message: QueuedMessage | MessageQueueItem) => {
        if (frozen) return;
        if (serverQueue.mode === 'server') {
            if (!serverQueue.scope || !draftKey) return;
            const currentDraft = useInputStore.getState().getDraft(draftKey);
            void serverQueue.actions.editIntoDraft(serverQueueEditInput(serverQueue.scope, message as MessageQueueItem, draftKey, currentDraft?.revision ?? 'absent')).then((result) => {
                if (result.status !== 'committed') toast.error(t('chat.chatInput.toast.messageSendFailed'));
            }).catch(() => toast.error(t('chat.chatInput.toast.messageSendFailed')));
            return;
        }
        const popped = popQueuedMessageForEdit(message as QueuedMessage, popToInput);
        if (popped) {
            const recovery = popped.failure?.recovery;
            const content = recovery?.content ?? popped.content;
            const attachments = recovery?.attachments ?? popped.attachments;
            if (attachments && attachments.length > 0) {
                const currentAttachments = useInputStore.getState().attachedFiles;
                useInputStore.getState().setAttachedFiles([...currentAttachments, ...attachments]);
            }
            onEditMessage(content, attachments, recovery?.composerDocument ?? popped.composerDocument, recovery?.composerMentions ?? popped.composerMentions);
        }
    });

    const handleSend = useEvent((message: QueuedMessage | MessageQueueItem) => {
        if (frozen) return;
        if (serverQueue.mode === 'server') {
            if (!serverQueue.scope) return;
            void serverQueue.actions.manualSend(serverQueueItemMutationInput(serverQueue.scope, message as MessageQueueItem, createUuid())).catch(() => toast.error(t('chat.chatInput.toast.messageSendFailed')));
            return;
        }
        const legacyMessage = message as QueuedMessage;
        onSendMessage(legacyMessage.queueItemID ?? legacyMessage.id);
    });

    const handleRemove = useEvent((message: QueuedMessage | MessageQueueItem) => {
        if (frozen) return;
        if (serverQueue.mode === 'server') {
            if (!serverQueue.scope) return;
            void serverQueue.actions.remove(serverQueueItemMutationInput(serverQueue.scope, message as MessageQueueItem, createUuid())).catch(() => toast.error(t('chat.chatInput.toast.messageSendFailed')));
            return;
        }
        const legacyMessage = message as QueuedMessage;
        if (legacyMessage.owner) useMessageQueueStore.getState().removeFromQueue(legacyMessage.owner, legacyMessage.queueItemID ?? legacyMessage.id, legacyMessage.operationID);
    });

    if (queuedMessages.length === 0 || !queueScope) {
        return null;
    }

    return (
        <div className={cn('w-full', isMobile ? 'pb-1' : 'px-0.5 pb-1.5 md:px-1 md:pb-2')}>
            <div className="overflow-hidden rounded-lg border border-border/60 bg-[var(--surface-elevated)] text-[var(--surface-elevated-foreground)] shadow-sm md:rounded-xl">
                <div className={cn(
                    'flex w-full items-center text-left',
                    isMobile
                        ? 'gap-1.5 border-b border-border/40 px-2 py-1'
                        : 'gap-1.5 px-2.5 py-1.5 md:gap-2 md:px-3 md:py-2',
                )}>
                    <span className={cn(
                        'flex-shrink-0 font-medium',
                        isMobile
                            ? 'text-xs leading-4 text-foreground'
                            : 'typography-micro leading-4 text-foreground md:typography-ui-label',
                    )}>
                        {t('chat.queuedMessage.title')}
                    </span>
                    <Icon
                        name="time"
                        className={cn(
                            'ml-auto text-muted-foreground',
                            isMobile ? 'size-3.5 opacity-80' : 'size-3.5 md:size-4',
                        )}
                        aria-hidden="true"
                    />
                </div>
                <DndContext
                    sensors={sensors}
                    collisionDetection={closestCenter}
                    onDragEnd={handleDragEnd}
                >
                    <SortableContext
                        items={queuedMessages.map((message) => message.queueItemID || (message as QueuedMessage).id)}
                        strategy={verticalListSortingStrategy}
                    >
                        <div className={cn(
                            'flex flex-col overflow-y-auto',
                            isMobile
                                ? 'max-h-[8rem] divide-y divide-border/30 py-0.5 pl-0 pr-1.5'
                                : 'max-h-[8rem] gap-1 px-2.5 pb-2 md:max-h-[10.5rem] md:gap-1.5 md:px-3 md:pb-3',
                        )}>
                            {queuedMessages.map((message) => (
                                <QueuedMessageChip
                                    key={message.queueItemID || (message as QueuedMessage).id}
                                    message={message}
                                    server={serverQueue.mode === 'server'}
                                    frozen={frozen}
                                    hasDispatchLock={hasDispatchLock}
                                    isMobile={isMobile}
                                    onEdit={handleEdit}
                                    onSend={handleSend}
                                    onRemove={handleRemove}
                                />
                            ))}
                        </div>
                    </SortableContext>
                </DndContext>
            </div>
        </div>
    );
});

QueuedMessageChips.displayName = 'QueuedMessageChips';
