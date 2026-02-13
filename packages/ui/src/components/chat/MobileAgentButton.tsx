import React from 'react';
import { cn } from '@/lib/utils';
import { useConfigStore } from '@/stores/useConfigStore';
import { useSessionStore } from '@/stores/useSessionStore';
import { getAgentDisplayName } from './mobileControlsUtils';
import { getAgentColor } from '@/lib/agentColors';

interface MobileAgentButtonProps {
    onOpenAgentPanel: () => void;
    className?: string;
}

export const MobileAgentButton: React.FC<MobileAgentButtonProps> = ({ onOpenAgentPanel, className }) => {
    const { currentAgentName, getVisibleAgents } = useConfigStore();
    const currentSessionId = useSessionStore((state) => state.currentSessionId);
    const sessionAgentName = useSessionStore((state) =>
        currentSessionId ? state.getSessionAgentSelection(currentSessionId) : null
    );

    const agents = getVisibleAgents();
    const uiAgentName = currentSessionId ? (sessionAgentName || currentAgentName) : currentAgentName;
    const agentLabel = getAgentDisplayName(agents, uiAgentName);
    const agentColor = getAgentColor(uiAgentName);

    return (
        <button
            type="button"
            onClick={onOpenAgentPanel}
            className={cn(
                'inline-flex min-w-0 items-center select-none',
                'rounded-lg border border-border/50 px-1.5',
                'typography-micro font-medium',
                'focus:outline-none hover:bg-[var(--interactive-hover)]',
                'touch-manipulation active:scale-95 transition-transform',
                className
            )}
            style={{
                height: '26px',
                maxHeight: '26px',
                minHeight: '26px',
                color: `var(${agentColor.var})`,
            }}
            title={agentLabel}
        >
            <span className="min-w-0 max-w-full overflow-x-auto whitespace-nowrap scrollbar-hidden">
                {agentLabel}
            </span>
        </button>
    );
};

export default MobileAgentButton;
