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
import { useQueueScopeDispatchFlight } from '@/hooks/useQueuedMessageAutoSend';
import { useUIStore } from '@/stores/useUIStore';
import { Icon } from "@/components/icon/Icon";
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { canSendQueuedMessage, mergeQueuedMessageScopes, popQueuedMessageForEdit } from './queuedMessageChipsState';

type BoundQueueScope = Extract<QueueScope, { state: 'bound' }>;

interface QueuedMessageChipProps {
    message: QueuedMessage;
    hasDispatchLock: boolean;
    isMobile: boolean;
    onEdit: (message: QueuedMessage) => void;
    onSend: (message: QueuedMessage) => void;
}

const QueuedMessageChip = memo(({ message, hasDispatchLock, isMobile, onEdit, onSend }: QueuedMessageChipProps) => {
    const { t } = useI18n();
    const removeFromQueue = useMessageQueueStore((state) => state.removeFromQueue);
    const status = message.status ?? 'queued';
    const isReadOnly = status === 'sending' || status === 'reconciling';
    const isDragDisabled = message.owner?.state === 'unbound-legacy' || isReadOnly;
    const canSend = canSendQueuedMessage(message, hasDispatchLock);
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
                'flex min-w-0 items-center',
                isMobile ? 'min-h-7 gap-1' : 'gap-1.5 py-0.5 md:gap-2 md:py-1',
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
                    isMobile ? 'size-6' : 'size-auto',
                    isDragDisabled ? 'cursor-default opacity-50' : 'cursor-grab hover:text-foreground active:cursor-grabbing',
                )}
                aria-label={t('chat.queuedMessage.reorderAria')}
            >
                <Icon name="draggable" className={cn(isMobile ? 'size-3' : 'size-3.5 md:size-4')} aria-hidden="true" />
            </button>
            <span className={cn(
                'min-w-0 flex-1 truncate text-foreground',
                isMobile ? 'typography-micro leading-none' : 'typography-micro leading-4 md:typography-ui-label',
            )}>
                {firstLine || t('chat.queuedMessage.empty')}
                {attachmentCount > 0 && (
                    <span className="ml-1 text-muted-foreground">{t('chat.queuedMessage.attachments', { count: attachmentCount })}</span>
                )}
            </span>
            <div className={cn('flex flex-shrink-0 items-center', isMobile ? 'gap-0.5' : 'gap-1.5')}>
                <Button
                    type="button"
                    variant={isMobile ? 'ghost' : 'secondary'}
                    size="xs"
                    className={isMobile ? 'h-6 gap-0.5 px-1.5 text-muted-foreground hover:text-foreground' : undefined}
                    onClick={() => onEdit(message)}
                    disabled={isReadOnly}
                >
                    <Icon name="edit" className="size-3" aria-hidden="true" />
                    {t('chat.queuedMessage.edit')}
                </Button>
                <Button
                    type="button"
                    variant={isMobile ? 'ghost' : 'secondary'}
                    size="xs"
                    className={isMobile ? 'h-6 gap-0.5 px-1.5 text-muted-foreground hover:text-foreground' : undefined}
                    onClick={() => onSend(message)}
                    disabled={!canSend}
                >
                    <Icon name="send-plane" className="size-3" aria-hidden="true" />
                    {t('chat.queuedMessage.send')}
                </Button>
                <button
                    type="button"
                    onClick={() => message.owner && removeFromQueue(message.owner, queueItemID, message.operationID)}
                    disabled={isReadOnly}
                    className={cn(
                        'flex flex-shrink-0 items-center justify-center text-muted-foreground transition-colors',
                        'hover:bg-[var(--interactive-hover)] hover:text-foreground',
                        'disabled:pointer-events-none disabled:opacity-50',
                        isMobile ? 'size-6 rounded-md' : 'size-6 rounded-full',
                    )}
                    aria-label={t('chat.queuedMessage.removeAria')}
                >
                    <Icon name="close" className={cn(isMobile ? 'size-3' : 'size-3.5')} aria-hidden="true" />
                </button>
            </div>
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
        onSendMessage(message.queueItemID ?? message.id);
    }, [onSendMessage]);

    if (queuedMessages.length === 0 || !queueScope) {
        return null;
    }

    return (
        <div className={cn('w-full px-0.5', isMobile ? 'pb-1' : 'pb-1.5 md:px-1 md:pb-2')}>
            <div className="overflow-hidden rounded-lg border border-border/60 bg-[var(--surface-elevated)] text-[var(--surface-elevated-foreground)] shadow-sm md:rounded-xl">
                <div className={cn(
                    'flex w-full items-center text-left',
                    isMobile
                        ? 'gap-1.5 border-b border-border/40 px-2.5 py-1.5'
                        : 'gap-1.5 px-2.5 py-1.5 md:gap-2 md:px-3 md:py-2',
                )}>
                    <span className={cn(
                        'flex-shrink-0 font-medium',
                        isMobile
                            ? 'typography-micro leading-none text-muted-foreground'
                            : 'typography-micro leading-4 text-foreground md:typography-ui-label',
                    )}>
                        {t('chat.queuedMessage.title')}
                    </span>
                    <Icon
                        name="time"
                        className={cn(
                            'ml-auto text-muted-foreground',
                            isMobile ? 'size-3 opacity-80' : 'size-3.5 md:size-4',
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
                        items={queuedMessages.map((message) => message.queueItemID ?? message.id)}
                        strategy={verticalListSortingStrategy}
                    >
                        <div className={cn(
                            'flex flex-col overflow-y-auto',
                            isMobile
                                ? 'max-h-[8rem] gap-0.5 px-1.5 py-1'
                                : 'max-h-[8rem] gap-1 px-2.5 pb-2 md:max-h-[10.5rem] md:gap-1.5 md:px-3 md:pb-3',
                        )}>
                            {queuedMessages.map((message) => (
                                <QueuedMessageChip
                                    key={message.queueItemID ?? message.id}
                                    message={message}
                                    hasDispatchLock={hasDispatchLock}
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
