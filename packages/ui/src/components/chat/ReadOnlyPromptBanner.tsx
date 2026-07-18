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

const ExecutionModelIcon: React.FC<{
    providerId?: string;
    modelId?: string;
    label: string;
}> = ({ providerId, modelId, label }) => {
    return (
        <span role="img" aria-label={label} className="relative inline-flex size-4 shrink-0 items-center justify-center">
            <Icon name="brain-ai-3" className="size-4" />
            <ModelLogo modelId={modelId} providerId={providerId} alt={label} className="absolute inset-0 size-4" />
        </span>
    );
};

export const ReadOnlyPromptBanner: React.FC<ReadOnlyPromptBannerProps> = (props) => {
    const { t } = useI18n();
    const showExecutionMetadata = 'agentName' in props || 'providerId' in props || 'modelId' in props || 'modelName' in props;
    if (!showExecutionMetadata) {
        return (
            <div className="p-3">
                <div className="rounded-2xl border border-border/70 bg-[var(--surface-background)] px-4 py-3 typography-ui-label text-muted-foreground">
                    {t('chat.container.readOnlySubagentPromptBanner')}
                </div>
            </div>
        );
    }

    const unavailable = t('common.unavailable');
    const agentName = props.agentName || unavailable;
    const modelName = props.modelName || unavailable;
    const agentLabel = `${t('chat.leaderKey.action.agent')}: ${agentName}`;
    const modelLabel = `${t('chat.leaderKey.action.model')}: ${modelName}`;

    return (
        <aside className="shrink-0 border-t border-border/70 bg-[var(--surface-background)] p-3">
            <div className="rounded-2xl border border-border/70 bg-[var(--surface-elevated)] px-4 py-3">
                <div className="typography-ui-label text-muted-foreground">{t('chat.container.readOnlySubagentPromptBanner')}</div>
                {showExecutionMetadata ? (
                    <div className="mt-2 flex min-w-0 flex-wrap gap-x-4 gap-y-2 border-t border-border/70 pt-2 typography-meta">
                        <div className="flex min-w-0 flex-1 basis-36 items-center gap-2">
                            <AgentAvatar name={props.agentName} size={16} label={agentLabel} />
                            <span className="min-w-0 truncate text-foreground" title={agentName}>{agentName}</span>
                        </div>
                        <div className="flex min-w-0 flex-1 basis-36 items-center gap-2">
                            <ExecutionModelIcon providerId={props.providerId} modelId={props.modelId} label={modelLabel} />
                            <span className="min-w-0 truncate text-foreground" title={modelName}>{modelName}</span>
                        </div>
                    </div>
                ) : null}
            </div>
        </aside>
    );
};
