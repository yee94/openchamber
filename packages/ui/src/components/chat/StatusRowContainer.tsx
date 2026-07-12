import React from 'react';

import { useAssistantStatus } from '@/hooks/useAssistantStatus';
import { useConfigStore } from '@/stores/useConfigStore';
import { useUIStore } from '@/stores/useUIStore';
import { abortCurrentOperation } from '@/sync/session-actions';
import { useSessionUIStore } from '@/sync/session-ui-store';
import { StatusRow } from './StatusRow';

/**
 * Status row wrapper.
 * Uses the dedicated assistant status hook so the row keeps accurate live activity
 * labels while still limiting subscriptions to the active assistant message.
 */
export const StatusRowContainer: React.FC = React.memo(() => {
    const currentSessionId = useSessionUIStore((state) => state.currentSessionId);
    const abortRecord = useSessionUIStore(
        React.useCallback((state) => {
            if (!currentSessionId) {
                return null;
            }
            return state.sessionAbortFlags?.get(currentSessionId) ?? null;
        }, [currentSessionId]),
    );
    const { working } = useAssistantStatus();
    const currentAgentName = useConfigStore((state) => state.currentAgentName);
    const isMobile = useUIStore((state) => state.isMobile);
    const handleAbort = React.useCallback(() => {
        if (!currentSessionId) return;
        void abortCurrentOperation(currentSessionId);
    }, [currentSessionId]);

    const wasAborted = Boolean(abortRecord && !abortRecord.acknowledged);

    return (
        <StatusRow
            isWorking={working.isWorking}
            statusText={working.statusText}
            isGenericStatus={working.isGenericStatus}
            isWaitingForPermission={working.isWaitingForPermission}
            wasAborted={wasAborted || working.wasAborted}
            abortActive={wasAborted || working.abortActive}
            retryInfo={working.retryInfo}
            showAbort={isMobile && working.canAbort}
            onAbort={handleAbort}
            showAssistantStatus
            showTodos={false}
            agentName={currentAgentName}
        />
    );
});

StatusRowContainer.displayName = 'StatusRowContainer';
