import React from 'react';
import { Icon } from "@/components/icon/Icon";
import { useI18n } from '@/lib/i18n';
import { useThemeSystem } from '@/contexts/useThemeSystem';
import { cn } from '@/lib/utils';
import { DRAFT_PRESETS, resolveDraftPresetText } from './draftPresets';

type DraftPresetChipsProps = {
    /** Called with the resolved text (command or prompt) when a chip is clicked. */
    onSubmit: (text: string) => void;
    /** Extra classes for the wrapper (e.g. width/spacing per surface). */
    className?: string;
};

/**
 * The row of starter preset chips shown on the draft welcome screen.
 * Rendering is shared between the desktop layout (under the composer) and the
 * narrow/compact layout (under the centered welcome message); the surface owns
 * how clicking a chip is submitted via `onSubmit`.
 */
export const DraftPresetChips: React.FC<DraftPresetChipsProps> = ({ onSubmit, className }) => {
    const { t } = useI18n();
    const { currentTheme } = useThemeSystem();

    return (
        <div className={cn('flex flex-wrap items-center justify-center gap-2', className)}>
            {DRAFT_PRESETS.map((preset) => (
                <button
                    key={preset.id}
                    type="button"
                    onClick={() => {
                        const text = resolveDraftPresetText(preset, t);
                        if (text) onSubmit(text);
                    }}
                    className="group inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-sm text-muted-foreground transition-colors hover:bg-[var(--interactive-hover)] hover:text-foreground"
                    style={{
                        backgroundColor: currentTheme?.colors?.surface?.elevated,
                        borderColor: currentTheme?.colors?.interactive?.border,
                    }}
                >
                    <Icon name={preset.icon} className="h-3.5 w-3.5 shrink-0 opacity-70 transition-opacity group-hover:opacity-100" />
                    <span>{t(preset.labelKey)}</span>
                </button>
            ))}
        </div>
    );
};
