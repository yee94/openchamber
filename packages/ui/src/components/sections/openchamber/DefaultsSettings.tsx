import React from 'react';
import { ModelSelector } from '@/components/sections/agents/ModelSelector';
import { AgentSelector } from '@/components/sections/commands/AgentSelector';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Checkbox } from '@/components/ui/checkbox';
import { Radio } from '@/components/ui/radio';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Button } from '@/components/ui/button';
import { updateDesktopSettings } from '@/lib/persistence';
import { useConfigStore } from '@/stores/useConfigStore';
import { useUIStore } from '@/stores/useUIStore';
import { getRegisteredRuntimeAPIs } from '@/contexts/runtimeAPIRegistry';
import { cn } from '@/lib/utils';
import { useI18n } from '@/lib/i18n';
import { parseModelIdentifier } from '@/lib/modelIdentifier';
import { runtimeFetch } from '@/lib/runtime-fetch';

const getDisplayModel = (
  storedModel: string | undefined
): { providerId: string; modelId: string } => {
  const parsed = parseModelIdentifier(storedModel);
  if (parsed) {
    return parsed;
  }

  return { providerId: '', modelId: '' };
};

const DEFAULT_SUMMARY_COMMIT_PROMPT = 'You are generating a Conventional Commits subject line from the diffs of the selected files.';

const DEFAULT_SESSION_TITLE_PROMPT = [
  'You are a title generator. You output ONLY a thread title. Nothing else.',
  'Generate a brief title that would help the user find this conversation later.',
  'Title the MAIN SUBJECT of the work - the overall feature, goal, or problem being done.',
  'Keep the title on the durable subject across follow-ups, polish, commit, push, tidy, and review turns.',
  'Switch the subject only when the user clearly starts a different topic or feature.',
  'Your output must be a single line of 50 characters or fewer with no explanation.',
  'Use the language of the user messages.',
  'Keep technical terms, numbers, filenames, and HTTP codes exact.',
  'Never include tool names, summarizing, or generating in the title.',
  'Always output a meaningful title.',
].join('\n');

export const DefaultsSettings: React.FC = () => {
  const { t } = useI18n();
  const setProvider = useConfigStore((state) => state.setProvider);
  const setModel = useConfigStore((state) => state.setModel);
  const setAgent = useConfigStore((state) => state.setAgent);
  const setCurrentVariant = useConfigStore((state) => state.setCurrentVariant);
  const setSettingsDefaultModel = useConfigStore((state) => state.setSettingsDefaultModel);
  const setSettingsDefaultVariant = useConfigStore((state) => state.setSettingsDefaultVariant);
  const setSettingsDefaultAgent = useConfigStore((state) => state.setSettingsDefaultAgent);
  const showDeletionDialog = useUIStore((state) => state.showDeletionDialog);
  const setShowDeletionDialog = useUIStore((state) => state.setShowDeletionDialog);
  const providers = useConfigStore((state) => state.providers);

  const [defaultModel, setDefaultModel] = React.useState<string | undefined>();
  const [defaultVariant, setDefaultVariant] = React.useState<string | undefined>();
  const [defaultAgent, setDefaultAgent] = React.useState<string | undefined>();
  const [summaryModelMode, setSummaryModelMode] = React.useState<'provider' | 'custom'>('provider');
  const [summaryProviderID, setSummaryProviderID] = React.useState('');
  const [summaryModelID, setSummaryModelID] = React.useState('');
  const [summaryCustomBaseURL, setSummaryCustomBaseURL] = React.useState('');
  const [summaryCustomAPIToken, setSummaryCustomAPIToken] = React.useState('');
  const [hasSummaryCustomAPIToken, setHasSummaryCustomAPIToken] = React.useState(false);
  const [summaryCommitPrompt, setSummaryCommitPrompt] = React.useState('');
  const [summarySessionTitlePrompt, setSummarySessionTitlePrompt] = React.useState('');
  const [isSavingSummarySettings, setIsSavingSummarySettings] = React.useState(false);
  const [isLoading, setIsLoading] = React.useState(true);

  const parsedModel = React.useMemo(() => getDisplayModel(defaultModel), [defaultModel]);

  React.useEffect(() => {
    const loadSettings = async () => {
      try {
        let data: {
          defaultModel?: string;
          defaultVariant?: string;
          defaultAgent?: string;
          summaryModelMode?: 'provider' | 'custom';
          summaryProviderID?: string;
          summaryModelID?: string;
          summaryCustomBaseURL?: string;
          hasSummaryCustomAPIToken?: boolean;
          summaryCommitPrompt?: string;
          summarySessionTitlePrompt?: string;
        } | null = null;

        if (!data) {
          const runtimeSettings = getRegisteredRuntimeAPIs()?.settings;
          if (runtimeSettings) {
            try {
              const result = await runtimeSettings.load();
              const settings = result?.settings;
              if (settings) {
                const raw = settings as Record<string, unknown>;
                data = {
                  defaultModel: typeof settings.defaultModel === 'string' ? settings.defaultModel : undefined,
                  defaultVariant:
                    typeof raw.defaultVariant === 'string'
                      ? (raw.defaultVariant as string)
                      : undefined,
                  defaultAgent: typeof settings.defaultAgent === 'string' ? settings.defaultAgent : undefined,
                  summaryModelMode: raw.summaryModelMode === 'provider' || raw.summaryModelMode === 'custom' ? raw.summaryModelMode : undefined,
                  summaryProviderID: typeof raw.summaryProviderID === 'string' ? raw.summaryProviderID : undefined,
                  summaryModelID: typeof raw.summaryModelID === 'string' ? raw.summaryModelID : undefined,
                  summaryCustomBaseURL: typeof raw.summaryCustomBaseURL === 'string' ? raw.summaryCustomBaseURL : undefined,
                  hasSummaryCustomAPIToken: typeof raw.hasSummaryCustomAPIToken === 'boolean' ? raw.hasSummaryCustomAPIToken : undefined,
                  summaryCommitPrompt: typeof raw.summaryCommitPrompt === 'string' ? raw.summaryCommitPrompt : undefined,
                  summarySessionTitlePrompt: typeof raw.summarySessionTitlePrompt === 'string' ? raw.summarySessionTitlePrompt : undefined,
                };
              }
            } catch {
              // fall through
            }
          }
        }

        if (!data) {
          const response = await runtimeFetch('/api/config/settings', {
            method: 'GET',
            headers: { Accept: 'application/json' },
          });
          if (response.ok) {
            data = await response.json();
          }
        }

        if (data) {
          const model =
            typeof data.defaultModel === 'string' && data.defaultModel.trim().length > 0
              ? data.defaultModel.trim()
              : undefined;
          const variant =
            typeof data.defaultVariant === 'string' && data.defaultVariant.trim().length > 0
              ? data.defaultVariant.trim()
              : undefined;
          const agent =
            typeof data.defaultAgent === 'string' && data.defaultAgent.trim().length > 0
              ? data.defaultAgent.trim()
              : undefined;

          if (model !== undefined) setDefaultModel(model);
          if (variant !== undefined) setDefaultVariant(variant);
          if (agent !== undefined) setDefaultAgent(agent);
          if (data.summaryModelMode) setSummaryModelMode(data.summaryModelMode);
          if (typeof data.summaryProviderID === 'string') setSummaryProviderID(data.summaryProviderID);
          if (typeof data.summaryModelID === 'string') setSummaryModelID(data.summaryModelID);
          if (typeof data.summaryCustomBaseURL === 'string') setSummaryCustomBaseURL(data.summaryCustomBaseURL);
          if (typeof data.hasSummaryCustomAPIToken === 'boolean') setHasSummaryCustomAPIToken(data.hasSummaryCustomAPIToken);
          setSummaryCommitPrompt(data.summaryCommitPrompt ?? DEFAULT_SUMMARY_COMMIT_PROMPT);
          setSummarySessionTitlePrompt(data.summarySessionTitlePrompt ?? DEFAULT_SESSION_TITLE_PROMPT);
        } else {
          setSummaryCommitPrompt(DEFAULT_SUMMARY_COMMIT_PROMPT);
          setSummarySessionTitlePrompt(DEFAULT_SESSION_TITLE_PROMPT);
        }
      } catch (error) {
        console.warn('Failed to load defaults settings:', error);
      } finally {
        setIsLoading(false);
      }
    };
    loadSettings();
  }, []);

  const handleModelChange = React.useCallback(
    async (providerId: string, modelId: string) => {
      const newValue = providerId && modelId ? `${providerId}/${modelId}` : undefined;
      setDefaultModel(newValue);
      setDefaultVariant(undefined);
      setSettingsDefaultVariant(undefined);
      setCurrentVariant(undefined);
      setSettingsDefaultModel(newValue);

      if (providerId && modelId) {
        const provider = providers.find((p) => p.id === providerId);
        if (provider) {
          setProvider(providerId);
          setModel(modelId);
        }
      }

      try {
        await updateDesktopSettings({ defaultModel: newValue ?? '', defaultVariant: '' });
        const response = await runtimeFetch('/api/config/settings', {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ defaultModel: newValue }),
        });
        if (!response.ok) {
          console.warn('Failed to save default model to server:', response.status, response.statusText);
        }
      } catch (error) {
        console.warn('Failed to save default model:', error);
      }
    },
    [providers, setCurrentVariant, setModel, setProvider, setSettingsDefaultModel, setSettingsDefaultVariant]
  );

  const DEFAULT_VARIANT_VALUE = '__default__';

  const formatVariantLabel = React.useCallback((variant: string) => {
    if (variant === DEFAULT_VARIANT_VALUE) {
      return t('settings.openchamber.defaults.option.default');
    }
    return variant.charAt(0).toUpperCase() + variant.slice(1);
  }, [t]);

  const handleVariantChange = React.useCallback(
    async (variant: string) => {
      const newValue = variant === DEFAULT_VARIANT_VALUE ? undefined : variant || undefined;
      setDefaultVariant(newValue);
      setSettingsDefaultVariant(newValue);
      setCurrentVariant(newValue);

      try {
        await updateDesktopSettings({ defaultVariant: newValue ?? '' });
      } catch (error) {
        console.warn('Failed to save default variant:', error);
      }
    },
    [setCurrentVariant, setSettingsDefaultVariant]
  );

  const handleAgentChange = React.useCallback(
    async (agentName: string) => {
      const newValue = agentName || undefined;
      setDefaultAgent(newValue);
      setSettingsDefaultAgent(newValue);

      if (agentName) {
        setAgent(agentName);
      }

      try {
        await updateDesktopSettings({ defaultAgent: newValue ?? '' });
      } catch (error) {
        console.warn('Failed to save default agent:', error);
      }
    },
    [setAgent, setSettingsDefaultAgent]
  );

  const defaultSummaryProvider = React.useMemo(
    () => providers.find((provider) => provider.id === 'openai') ?? providers[0],
    [providers],
  );

  React.useEffect(() => {
    if (!summaryProviderID && defaultSummaryProvider?.id) {
      setSummaryProviderID(defaultSummaryProvider.id);
    }
  }, [defaultSummaryProvider?.id, summaryProviderID]);

  const handleSaveSummarySettings = React.useCallback(async () => {
    setIsSavingSummarySettings(true);
    try {
      const changes: Parameters<typeof updateDesktopSettings>[0] = {
        summaryModelMode,
        summaryProviderID: summaryProviderID.trim(),
        summaryModelID: summaryModelID.trim(),
        summaryCustomBaseURL,
        summaryCommitPrompt,
        summarySessionTitlePrompt,
      };
      if (summaryCustomAPIToken.trim()) {
        changes.summaryCustomAPIToken = summaryCustomAPIToken;
      }
      await updateDesktopSettings(changes);
      if (summaryCustomAPIToken.trim()) {
        setHasSummaryCustomAPIToken(true);
      }
      setSummaryCustomAPIToken('');
    } catch (error) {
      console.warn('Failed to save summary settings:', error);
    } finally {
      setIsSavingSummarySettings(false);
    }
  }, [summaryCommitPrompt, summaryCustomAPIToken, summaryCustomBaseURL, summaryModelID, summaryModelMode, summaryProviderID, summarySessionTitlePrompt]);

  const handleClearSummaryToken = React.useCallback(async () => {
    setIsSavingSummarySettings(true);
    try {
      await updateDesktopSettings({ summaryCustomAPIToken: '' });
      setSummaryCustomAPIToken('');
      setHasSummaryCustomAPIToken(false);
    } catch (error) {
      console.warn('Failed to clear summary API token:', error);
    } finally {
      setIsSavingSummarySettings(false);
    }
  }, []);

  const availableVariants = React.useMemo(() => {
    if (!parsedModel.providerId || !parsedModel.modelId) return [];
    const provider = providers.find((p) => p.id === parsedModel.providerId);
    const model = provider?.models.find((m: Record<string, unknown>) => (m as { id?: string }).id === parsedModel.modelId) as
      | { variants?: Record<string, unknown> }
      | undefined;
    const variants = model?.variants;
    if (!variants) return [];
    return Object.keys(variants);
  }, [parsedModel.modelId, parsedModel.providerId, providers]);

  const supportsVariants = availableVariants.length > 0;

  React.useEffect(() => {
    if (!supportsVariants && defaultVariant) {
      setDefaultVariant(undefined);
      setSettingsDefaultVariant(undefined);
      setCurrentVariant(undefined);
      updateDesktopSettings({ defaultVariant: '' }).catch(() => {
        // best effort
      });
    }
  }, [defaultVariant, setCurrentVariant, setSettingsDefaultVariant, supportsVariants]);

  if (isLoading) {
    return null;
  }

  return (
    <div className="mb-6">
      <div className="mb-0.5 px-1">
        <div className="flex items-center gap-2">
          <h3 className="typography-ui-header font-medium text-foreground">{t('settings.openchamber.defaults.title')}</h3>
        </div>
      </div>

      <section className="px-2 pb-2 pt-0 space-y-0">
        <div className="mt-0 mb-1 typography-meta text-muted-foreground">
          {t('settings.openchamber.defaults.summaryPrefix')}
          {' '}
          {parsedModel.providerId ? (
            <span className="text-foreground">
              {parsedModel.providerId}/{parsedModel.modelId}
              {supportsVariants ? ` (${defaultVariant ?? t('settings.openchamber.defaults.option.defaultLowercase')})` : ''}
            </span>
          ) : (
            <span className="text-foreground">{t('settings.openchamber.defaults.summaryOpenCodeDefault')}</span>
          )}
          {defaultAgent && (
            <>
              {' / '}
              <span className="text-foreground">{defaultAgent}</span>
            </>
          )}
        </div>

        <div data-settings-item="sessions.default-model" className={cn('flex flex-col gap-2 py-1 sm:flex-row sm:items-center sm:gap-8')}>
          <div className="flex min-w-0 flex-col sm:w-56 shrink-0">
            <span className="typography-ui-label text-foreground">{t('settings.openchamber.defaults.field.defaultModel')}</span>
          </div>
          <div className="flex min-w-0 flex-1 items-center gap-2 sm:w-fit sm:flex-initial">
            <ModelSelector providerId={parsedModel.providerId} modelId={parsedModel.modelId} onChange={handleModelChange} />
          </div>
        </div>

        <div data-settings-item="sessions.default-thinking" className="flex flex-col gap-2 py-1 sm:flex-row sm:items-center sm:gap-8">
          <div className="flex min-w-0 flex-col sm:w-56 shrink-0">
            <span className="typography-ui-label text-foreground">{t('settings.openchamber.defaults.field.defaultThinking')}</span>
          </div>
          <div className="flex items-center gap-2 sm:w-fit">
            <Select value={defaultVariant ?? DEFAULT_VARIANT_VALUE} onValueChange={handleVariantChange} disabled={!supportsVariants}>
              <SelectTrigger className="w-fit min-w-[120px]">
                <SelectValue placeholder={t('settings.openchamber.defaults.field.thinkingPlaceholder')}>
                  {formatVariantLabel(defaultVariant ?? DEFAULT_VARIANT_VALUE)}
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={DEFAULT_VARIANT_VALUE}>{t('settings.openchamber.defaults.option.default')}</SelectItem>
                {availableVariants.map((variant) => (
                  <SelectItem key={variant} value={variant}>
                    {formatVariantLabel(variant)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        <div data-settings-item="sessions.default-agent" className="flex flex-col gap-2 py-1 sm:flex-row sm:items-center sm:gap-8">
          <div className="flex min-w-0 flex-col sm:w-56 shrink-0">
            <span className="typography-ui-label text-foreground">{t('settings.openchamber.defaults.field.defaultAgent')}</span>
          </div>
          <div className="flex min-w-0 flex-1 items-center gap-2 sm:w-fit sm:flex-initial">
            <AgentSelector agentName={defaultAgent || ''} onChange={handleAgentChange} />
          </div>
        </div>

        <div
          data-settings-item="sessions.deletion-dialog"
          className="group flex cursor-pointer items-center gap-2 py-1"
          role="button"
          tabIndex={0}
          aria-pressed={showDeletionDialog}
          onClick={() => setShowDeletionDialog(!showDeletionDialog)}
          onKeyDown={(event) => {
            if (event.key === ' ' || event.key === 'Enter') {
              event.preventDefault();
              setShowDeletionDialog(!showDeletionDialog);
            }
          }}
        >
          <Checkbox checked={showDeletionDialog} onChange={setShowDeletionDialog} ariaLabel={t('settings.openchamber.defaults.field.showDeletionDialogAria')} />
          <span className="typography-ui-label text-foreground">{t('settings.openchamber.defaults.field.showDeletionDialog')}</span>
        </div>

      </section>

      <div className="mt-6 mb-0.5 px-1">
        <h3 className="typography-ui-header font-medium text-foreground">{t('settings.openchamber.defaults.summary.title')}</h3>
      </div>

      <section data-settings-item="sessions.summary-ai" className="space-y-4 px-2 pb-2 pt-0">
        <div className="typography-meta text-muted-foreground">
          {t('settings.openchamber.defaults.summary.description')}
        </div>

        <div role="radiogroup" aria-label={t('settings.openchamber.defaults.summary.modelSourceAria')} className="space-y-1">
          <div className="flex items-center gap-2 py-0.5">
            <Radio
              checked={summaryModelMode === 'provider'}
              onChange={() => setSummaryModelMode('provider')}
              ariaLabel={t('settings.openchamber.defaults.summary.provider')}
            />
            <span className={summaryModelMode === 'provider' ? 'typography-ui-label text-foreground' : 'typography-ui-label text-foreground/50'}>
              {t('settings.openchamber.defaults.summary.provider')}
            </span>
          </div>
          <div className="flex items-center gap-2 py-0.5">
            <Radio
              checked={summaryModelMode === 'custom'}
              onChange={() => setSummaryModelMode('custom')}
              ariaLabel={t('settings.openchamber.defaults.summary.custom')}
            />
            <span className={summaryModelMode === 'custom' ? 'typography-ui-label text-foreground' : 'typography-ui-label text-foreground/50'}>
              {t('settings.openchamber.defaults.summary.custom')}
            </span>
          </div>
        </div>

        {summaryModelMode === 'provider' ? (
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:gap-8">
            <span className="typography-ui-label text-foreground sm:w-56 shrink-0">{t('settings.openchamber.defaults.summary.providerModel')}</span>
            <ModelSelector
              providerId={summaryProviderID}
              modelId={summaryModelID}
              onChange={(providerID, modelID) => {
                setSummaryProviderID(providerID);
                setSummaryModelID(modelID);
              }}
            />
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-2 md:grid-cols-2 md:gap-3">
            <label className="space-y-1">
              <span className="typography-ui-label text-foreground">{t('settings.openchamber.defaults.summary.baseUrl')}</span>
              <Input value={summaryCustomBaseURL} onChange={(event) => setSummaryCustomBaseURL(event.target.value)} placeholder={t('settings.openchamber.defaults.summary.baseUrlPlaceholder')} />
            </label>
            <label className="space-y-1">
              <span className="typography-ui-label text-foreground">{t('settings.openchamber.defaults.summary.modelId')}</span>
              <Input value={summaryModelID} onChange={(event) => setSummaryModelID(event.target.value)} placeholder={t('settings.openchamber.defaults.summary.modelIdPlaceholder')} />
            </label>
            <label className="space-y-1 md:col-span-2">
              <span className="typography-ui-label text-foreground">{t('settings.openchamber.defaults.summary.apiToken')}</span>
              <div className="flex flex-wrap items-center gap-2">
                <Input type="password" value={summaryCustomAPIToken} onChange={(event) => setSummaryCustomAPIToken(event.target.value)} placeholder={hasSummaryCustomAPIToken ? t('settings.openchamber.defaults.summary.apiTokenStored') : t('settings.openchamber.defaults.summary.apiTokenPlaceholder')} className="max-w-xl" />
                {hasSummaryCustomAPIToken ? (
                  <Button variant="outline" size="sm" onClick={() => void handleClearSummaryToken()} disabled={isSavingSummarySettings}>
                    {t('settings.openchamber.defaults.summary.clearToken')}
                  </Button>
                ) : null}
              </div>
            </label>
          </div>
        )}

        <div className="grid grid-cols-1 gap-3 md:grid-cols-2 md:gap-3">
          <label className="space-y-1">
            <span className="typography-ui-label text-foreground">{t('settings.openchamber.defaults.summary.commitPrompt')}</span>
            <Textarea value={summaryCommitPrompt} onChange={(event) => setSummaryCommitPrompt(event.target.value)} placeholder={t('settings.openchamber.defaults.summary.commitPromptPlaceholder')} className="min-h-36 font-mono text-sm" />
          </label>
          <label className="space-y-1">
            <span className="typography-ui-label text-foreground">{t('settings.openchamber.defaults.summary.sessionTitlePrompt')}</span>
            <Textarea value={summarySessionTitlePrompt} onChange={(event) => setSummarySessionTitlePrompt(event.target.value)} placeholder={t('settings.openchamber.defaults.summary.sessionTitlePromptPlaceholder')} className="min-h-36 font-mono text-sm" />
          </label>
        </div>

        <div className="flex items-center justify-end">
          <Button size="sm" onClick={() => void handleSaveSummarySettings()} disabled={isSavingSummarySettings}>
            {isSavingSummarySettings ? t('settings.common.actions.saving') : t('settings.openchamber.defaults.summary.save')}
          </Button>
        </div>
      </section>
    </div>
  );
};
