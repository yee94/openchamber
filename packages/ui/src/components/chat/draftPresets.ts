import type { IconName } from "@/components/icon/icons";
import type { I18nKey } from "@/lib/i18n";

// Starter presets shown on the draft welcome screen — under the composer on
// desktop, and under the centered welcome message on narrow surfaces
// (mobile/vscode). `command` presets send a built-in slash command through the
// normal submit path; `promptKey` presets send a plain natural-language prompt.
export type DraftPreset = {
    id: string;
    icon: IconName;
    labelKey: I18nKey;
    promptKey?: I18nKey;
    command?: string;
};

export const DRAFT_PRESETS: readonly DraftPreset[] = [
    { id: 'explore', icon: 'compass-3', labelKey: 'chat.draftPresets.explore.label', command: '/explore' },
    { id: 'catchup', icon: 'history', labelKey: 'chat.draftPresets.catchup.label', command: '/catch-up' },
    { id: 'weigh', icon: 'scales-3', labelKey: 'chat.draftPresets.weigh.label', command: '/weigh' },
    { id: 'plan', icon: 'survey', labelKey: 'chat.draftPresets.plan.label', command: '/plan-feature' },
    { id: 'debug', icon: 'bug', labelKey: 'chat.draftPresets.debug.label', command: '/debug' },
    { id: 'review', icon: 'search-eye', labelKey: 'chat.draftPresets.review.label', command: '/workspace-review' },
];

// Resolve the text a preset submits: a slash command, or a translated prompt.
export const resolveDraftPresetText = (
    preset: DraftPreset,
    t: (key: I18nKey) => string,
): string => preset.command ?? (preset.promptKey ? t(preset.promptKey) : '');
