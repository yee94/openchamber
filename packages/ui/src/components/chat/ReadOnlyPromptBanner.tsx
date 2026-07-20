import React from 'react';

import { AgentAvatar } from '@/components/chat/AgentAvatar';
import { Icon } from '@/components/icon/Icon';
import { ModelLogo } from '@/components/ui/ModelLogo';
import { useI18n } from '@/lib/i18n';

type ReadOnlyPromptBannerProps = {
    agentName?: string;
    providerId?: string;
    modelId?: string;
    modelName?: string;
};

/** Mobile needs an explicit size: `.typography-*` is unset on mobile-pointer. */
const BANNER_TEXT_CLASS = 'text-[13px] leading-4 sm:text-[length:var(--text-micro)] sm:leading-5';

const ExecutionModelIcon: React.FC<{
    providerId?: string;
    modelId?: string;
    label: string;
}> = ({ providerId, modelId, label }) => {
    return (
        <ModelLogo
            modelId={modelId}
            providerId={providerId}
            alt={label}
            className="size-3.5 shrink-0"
            fallback={(
                <span role="img" aria-label={label} className="inline-flex size-3.5 shrink-0 items-center justify-center">
                    <Icon name="brain-ai-3" className="size-3.5" />
                </span>
            )}
        />
    );
};

export const ReadOnlyPromptBanner: React.FC<ReadOnlyPromptBannerProps> = (props) => {
    const { t } = useI18n();
    const showExecutionMetadata = 'agentName' in props || 'providerId' in props || 'modelId' in props || 'modelName' in props;
    if (!showExecutionMetadata) {
        return (
            <div className="p-3">
                <div className={`rounded-2xl border border-border/70 bg-[var(--surface-background)] px-4 py-3 text-muted-foreground ${BANNER_TEXT_CLASS}`}>
                    {t('chat.container.readOnlySubagentPromptBanner')}
                </div>
            </div>
        );
    }

    const unavailable = t('common.unavailable');
    const agentName = props.agentName
        ? props.agentName.charAt(0).toUpperCase() + props.agentName.slice(1)
        : unavailable;
    const modelName = props.modelName || unavailable;
    const agentLabel = `${t('chat.leaderKey.action.agent')}: ${agentName}`;
    const modelLabel = `${t('chat.leaderKey.action.model')}: ${modelName}`;

    return (
        <aside className="shrink-0 border-t border-border/70 bg-[var(--surface-background)] p-3">
            <div className="rounded-2xl border border-border/70 bg-[var(--surface-elevated)] px-3 py-2.5 sm:px-4 sm:py-3">
                <div className={`text-muted-foreground ${BANNER_TEXT_CLASS}`}>
                    {t('chat.container.readOnlySubagentPromptBanner')}
                </div>
                {showExecutionMetadata ? (
                    <div
                        data-testid="read-only-prompt-banner-meta"
                        className={`mt-1.5 flex min-w-0 items-center justify-between gap-3 border-t border-border/70 pt-1.5 ${BANNER_TEXT_CLASS}`}
                    >
                        <div className="flex min-w-0 items-center gap-1.5 overflow-hidden">
                            <AgentAvatar name={props.agentName} size={14} label={agentLabel} />
                            <span className="min-w-0 truncate text-foreground" title={agentName}>{agentName}</span>
                        </div>
                        <div className="flex min-w-0 max-w-[55%] items-center justify-end gap-1.5 overflow-hidden">
                            <ExecutionModelIcon providerId={props.providerId} modelId={props.modelId} label={modelLabel} />
                            <span className="min-w-0 truncate text-right text-foreground" title={modelName}>{modelName}</span>
                        </div>
                    </div>
                ) : null}
            </div>
        </aside>
    );
};
