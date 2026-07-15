import React from 'react';
import type { Part } from '@opencode-ai/sdk/v2';
import type { ContentChangeReason } from '@/hooks/useChatAutoFollow';
import { useUIStore } from '@/stores/useUIStore';
import { ReasoningTimelineBlock } from './ReasoningPart';
import type { StreamPhase } from '../types';
import {
    emitStreamingHapticEvent,
    evaluateVisiblePartHaptic,
    hasStreamingHapticSubscribers,
    type VisiblePartHapticState,
} from '@/sync/streaming-haptic-events';

type PartWithText = Part & { text?: string; content?: string; time?: { start?: number; end?: number } };
type PartWithSession = Part & { sessionID?: string };

const cleanJustificationText = (text: string): string => {
    if (typeof text !== 'string' || text.trim().length === 0) {
        return '';
    }

    return text
        .split('\n')
        .map((line: string) => line.replace(/^>\s?/, '').trimEnd())
        .filter((line: string) => line.trim().length > 0)
        .join('\n')
        .trim();
};

interface JustificationBlockProps {
    part: Part;
    messageId: string;
    onContentChange?: (reason?: ContentChangeReason) => void;
    actions?: React.ReactNode;
    streamPhase?: StreamPhase;
}

const JustificationBlock: React.FC<JustificationBlockProps> = ({
    part,
    messageId,
    onContentChange,
    actions,
    streamPhase,
}) => {
    const chatRenderMode = useUIStore((state) => state.chatRenderMode);
    const partWithText = part as PartWithText;
    const rawText = partWithText.text || partWithText.content || '';
    const textContent = React.useMemo(() => cleanJustificationText(rawText), [rawText]);
    const time = partWithText.time;
    const sessionID = (part as PartWithSession).sessionID;
    const hapticIdentity = `${messageId}:${part.id ?? 'justification'}`;
    const hapticStateRef = React.useRef<VisiblePartHapticState | null>(null);
    const canBeStreaming = streamPhase === undefined || streamPhase !== 'completed';
    const isHapticActive = canBeStreaming && typeof time?.end !== 'number';

    React.useEffect(() => {
        if (!hasStreamingHapticSubscribers()) return;
        const decision = evaluateVisiblePartHaptic(hapticStateRef.current, {
            identity: hapticIdentity,
            content: textContent,
            isActive: isHapticActive,
            mode: 'changes',
        });
        hapticStateRef.current = decision.nextState;

        if (!decision.shouldEmit || !sessionID) return;
        emitStreamingHapticEvent({ sessionID, messageID: messageId, partID: part.id, kind: 'text' });
    }, [hapticIdentity, isHapticActive, messageId, part.id, sessionID, textContent]);

    // Don't render if there's no text content
    if (!textContent || textContent.trim().length === 0) {
        return null;
    }

    return (
        <ReasoningTimelineBlock
            text={textContent}
            variant="justification"
            onContentChange={onContentChange}
            blockId={part.id || `${messageId}-justification`}
            time={time}
            showDuration={chatRenderMode !== 'sorted'}
            actions={actions}
        />
    );
};

export default React.memo(JustificationBlock);
