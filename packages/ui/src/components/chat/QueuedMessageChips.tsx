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
import { getQueueForScope, legacyQueueScope, queueScopeKey, useMessageQueueStore, type QueueScope, type QueuedMessage } from '@/stores/messageQueueStore';
import { useSessionUIStore } from '@/sync/session-ui-store';
import { useInputStore } from '@/sync/input-store';
import { useI18n } from '@/lib/i18n';
import { getRuntimeTransportIdentity, subscribeRuntimeEndpointChanged } from '@/lib/runtime-switch';
import { useEffectiveDirectory } from '@/hooks/useEffectiveDirectory';
import { useUIStore } from '@/stores/useUIStore';
import { Icon } from "@/components/icon/Icon";
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { mergeQueuedMessageScopes, popQueuedMessageForEdit } from './queuedMessageChipsState';

type BoundQueueScope = Extract<QueueScope, { state: 'bound' }>;

interface QueuedMessageChipProps {
    message: QueuedMessage;
    isQueueHead: boolean;
    isMobile: boolean;
    onEdit: (message: QueuedMessage) => void;
    onSend: (message: QueuedMessage) => void;
}

const QueuedMessageChip = memo(({ message, isQueueHead, isMobile, onEdit, onSend }: QueuedMessageChipProps) => {
    const { t } = useI18n();
    const removeFromQueue = useMessageQueueStore((state) => state.removeFromQueue);
    const status = message.status ?? 'queued';
    const isReadOnly = status === 'sending' || status === 'reconciling';
    const isDragDisabled = message.owner?.state === 'unbound-legacy' || isReadOnly;
    // Head items in a recoverable terminal/retry state can be force-sent.
    // Locked in-flight states stay disabled until recover/reconcile finishes.
    const canSend = isQueueHead && !isReadOnly && (
      status === 'queued'
      || status === 'retrying'
      || status === 'failed'
      || status === 'unresolved'
    );
    const queueItemID = message.queueItemID ?? message.id;
    const recovery = message.failure?.recovery;
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
                'flex min-w-0 items-center gap-1.5',
                isMobile ? 'py-0' : 'py-0.5 md:gap-2 md:py-1',
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
                    isDragDisabled ? 'cursor-default opacity-50' : 'cursor-grab hover:text-foreground active:cursor-grabbing',
                )}
                aria-label={t('chat.queuedMessage.reorderAria')}
            >
                <Icon name="draggable" className="size-3.5 md:size-4" aria-hidden="true" />
            </button>
            <span className="min-w-0 flex-1 truncate typography-micro leading-4 text-foreground md:typography-ui-label">
                {firstLine || t('chat.queuedMessage.empty')}
                {attachmentCount > 0 && (
                    <span className="ml-1 text-muted-foreground">{t('chat.queuedMessage.attachments', { count: attachmentCount })}</span>
                )}
            </span>
            <Button
                type="button"
                variant="secondary"
                size="xs"
                onClick={() => onEdit(message)}
                disabled={isReadOnly}
            >
                <Icon name="edit" className="h-3 w-3" aria-hidden="true" />
                {t('chat.queuedMessage.edit')}
            </Button>
            <Button
                type="button"
                variant="secondary"
                size="xs"
                onClick={() => onSend(message)}
                disabled={!canSend}
            >
                <Icon name="send-plane" className="h-3 w-3" aria-hidden="true" />
                {t('chat.queuedMessage.send')}
            </Button>
            <button
                type="button"
                onClick={() => message.owner && removeFromQueue(message.owner, queueItemID, message.operationID)}
                disabled={isReadOnly}
                className="flex items-center justify-center h-6 w-6 flex-shrink-0 hover:bg-[var(--interactive-hover)] rounded-full transition-colors disabled:pointer-events-none disabled:opacity-50"
                aria-label={t('chat.queuedMessage.removeAria')}
            >
                <Icon name="close" className="h-4 w-4 text-muted-foreground" />
            </button>
        </div>
    );
});

QueuedMessageChip.displayName = 'QueuedMessageChip';

interface QueuedMessageChipsProps {
    onEditMessage: (content: string, attachments?: QueuedMessage['attachments']) => void;
    onSendMessage: (messageId: string) => void;
}

const EMPTY_QUEUE: QueuedMessage[] = [];
const subscribeRuntimeTransport = (notify: () => void) => subscribeRuntimeEndpointChanged(() => notify());

export const QueuedMessageChips = memo(({ onEditMessage, onSendMessage }: QueuedMessageChipsProps) => {
    const { t } = useI18n();
    const isMobile = useUIStore((state) => state.isMobile);
    const currentSessionId = useSessionUIStore((state) => state.currentSessionId);
    const fallbackDirectory = useEffectiveDirectory();
    const currentSessionDirectory = useSessionUIStore(
        React.useCallback(
            (state) => currentSessionId ? state.getDirectoryForSession(currentSessionId) : null,
            [currentSessionId],
        ),
    );
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
    const legacyScope = React.useMemo(() => currentSessionId ? legacyQueueScope(currentSessionId) : null, [currentSessionId]);
    const boundQueuedMessages = useMessageQueueStore(
        React.useCallback(
            (state) => {
                return queueScope ? getQueueForScope(state, queueScope) : EMPTY_QUEUE;
            },
            [queueScope]
        )
    );
    const legacyQueuedMessages = useMessageQueueStore(
        React.useCallback(
            (state) => {
                return legacyScope ? getQueueForScope(state, legacyScope) : EMPTY_QUEUE;
            },
            [legacyScope]
        )
    );
    const queuedMessages = React.useMemo(
        () => mergeQueuedMessageScopes(legacyQueuedMessages, boundQueuedMessages),
        [boundQueuedMessages, legacyQueuedMessages],
    );
    const popToInput = useMessageQueueStore((state) => state.popToInput);
    const reorderQueue = useMessageQueueStore((state) => state.reorderQueue);
    const bindLegacyQueue = useMessageQueueStore((state) => state.bindLegacyQueue);

    const sensors = useSensors(
        // Desktop: drag after a small move so other clicks still register.
        useSensor(MouseSensor, { activationConstraint: { distance: 8 } }),
        // Touch: long-press to drag (tap still hits buttons, swipe scrolls).
        useSensor(TouchSensor, { activationConstraint: { delay: 200, tolerance: 6 } }),
    );

    const handleDragEnd = React.useCallback((event: DragEndEvent) => {
        const { active, over } = event;
        if (!over || active.id === over.id) return;
        const activeMessage = queuedMessages.find((message) => (message.queueItemID ?? message.id) === active.id);
        const overMessage = queuedMessages.find((message) => (message.queueItemID ?? message.id) === over.id);
        if (!activeMessage || !overMessage) return;
        const activeScope = activeMessage.owner;
        const overScope = overMessage.owner;
        if (activeScope?.state !== 'bound' || overScope?.state !== 'bound' || queueScopeKey(activeScope) !== queueScopeKey(overScope)) return;
        reorderQueue(activeScope, String(active.id), String(over.id), activeMessage.operationID);
    }, [queuedMessages, reorderQueue]);

    const handleEdit = React.useCallback((message: QueuedMessage) => {
        const popped = popQueuedMessageForEdit(message, popToInput);
        if (popped) {
            const recovery = popped.failure?.recovery;
            const content = recovery?.content ?? popped.content;
            const attachments = recovery?.attachments ?? popped.attachments;
            if (attachments && attachments.length > 0) {
                const currentAttachments = useInputStore.getState().attachedFiles;
                useInputStore.getState().setAttachedFiles([...currentAttachments, ...attachments]);
            }
            onEditMessage(content, attachments);
        }
    }, [popToInput, onEditMessage]);

    const handleSend = React.useCallback((message: QueuedMessage) => {
        if (message.owner?.state === 'unbound-legacy') {
            if (!queueScope) return;
            bindLegacyQueue(message.owner, queueScope);
        }
        onSendMessage(message.queueItemID ?? message.id);
    }, [bindLegacyQueue, onSendMessage, queueScope]);

    if (queuedMessages.length === 0 || !queueScope) {
        return null;
    }

    return (
        <div className={cn('w-full px-0.5', isMobile ? 'pb-1 text-xs' : 'pb-1.5 md:px-1 md:pb-2')}>
            <div className="overflow-hidden rounded-lg border border-border/60 bg-[var(--surface-elevated)] text-[var(--surface-elevated-foreground)] shadow-sm md:rounded-xl">
                <div className={cn(
                    'flex w-full items-center gap-1.5 text-left',
                    isMobile ? 'px-2 py-1' : 'px-2.5 py-1.5 md:gap-2 md:px-3 md:py-2',
                )}>
                    <span className="flex-shrink-0 typography-micro font-medium leading-4 text-foreground md:typography-ui-label">
                        {t('chat.queuedMessage.title', { count: queuedMessages.length })}
                    </span>
                    <Icon name="time" className="ml-auto size-3.5 text-muted-foreground md:size-4" aria-hidden="true" />
                </div>
                <DndContext
                    sensors={sensors}
                    collisionDetection={closestCenter}
                    onDragEnd={handleDragEnd}
                >
                    <SortableContext
                        items={queuedMessages.map((message) => message.queueItemID ?? message.id)}
                        strategy={verticalListSortingStrategy}
                    >
                        <div className={cn(
                            'flex flex-col gap-1 overflow-y-auto',
                            isMobile
                                ? 'max-h-[8rem] px-2 pb-1.5'
                                : 'max-h-[8rem] px-2.5 pb-2 md:max-h-[10.5rem] md:gap-1.5 md:px-3 md:pb-3',
                        )}>
                            {queuedMessages.map((message, index) => (
                                <QueuedMessageChip
                                    key={message.queueItemID ?? message.id}
                                    message={message}
                                    isQueueHead={index === 0}
                                    isMobile={isMobile}
                                    onEdit={handleEdit}
                                    onSend={handleSend}
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
