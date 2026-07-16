export type PermissionAutoAcceptToggleArgs = {
    permissionScopeSessionId: string | null;
    newSessionDraftOpen: boolean;
    draftPermissionAutoAcceptEnabled: boolean;
    permissionAutoAcceptEnabled: boolean;
    setDraftPermissionAutoAcceptEnabled: (enabled: boolean) => void;
    setSessionAutoAccept: (sessionId: string, enabled: boolean) => Promise<void>;
    onOpenSessionFirst: () => void;
    onToggleFailed: () => void;
};

type PermissionAction = 'allow' | 'ask' | 'deny';

type PermissionRule = {
    permission: string;
    pattern: string;
    action: PermissionAction;
};

type PermissionAgent = {
    name?: unknown;
    permission?: unknown;
};

const isPermissionAction = (value: unknown): value is PermissionAction => (
    value === 'allow' || value === 'ask' || value === 'deny'
);

const normalizePermissionRules = (value: unknown): PermissionRule[] => {
    if (isPermissionAction(value)) {
        return [{ permission: '*', pattern: '*', action: value }];
    }

    if (Array.isArray(value)) {
        return value.flatMap((entry): PermissionRule[] => {
            if (!entry || typeof entry !== 'object') return [];
            const rule = entry as Partial<PermissionRule>;
            return typeof rule.permission === 'string'
                && typeof rule.pattern === 'string'
                && isPermissionAction(rule.action)
                ? [{ permission: rule.permission, pattern: rule.pattern, action: rule.action }]
                : [];
        });
    }

    if (!value || typeof value !== 'object') return [];

    const rules: PermissionRule[] = [];
    for (const [permission, config] of Object.entries(value)) {
        if (permission === '__originalKeys') continue;
        if (isPermissionAction(config)) {
            rules.push({ permission, pattern: '*', action: config });
            continue;
        }
        if (!config || typeof config !== 'object' || Array.isArray(config)) continue;
        for (const [pattern, action] of Object.entries(config)) {
            if (isPermissionAction(action)) rules.push({ permission, pattern, action });
        }
    }
    return rules;
};

const canPermissionRulesPrompt = (permission: unknown): boolean => {
    const rules = normalizePermissionRules(permission);
    for (let index = rules.length - 1; index >= 0; index -= 1) {
        const rule = rules[index];
        if (rule.permission === '*' && rule.pattern === '*') return rule.action === 'ask';
        if (rule.action === 'ask') return true;
    }
    return true;
};

/** Unknown agent snapshots and configurations keep the control available. */
export const shouldShowPermissionAutoAcceptControl = (
    agents: readonly PermissionAgent[],
    currentAgentName: string | undefined,
): boolean => {
    const name = currentAgentName?.trim();
    if (!name) {
        return agents.length === 0 || agents.some((agent) => canPermissionRulesPrompt(agent.permission));
    }
    const agent = agents.find((entry) => entry?.name === name);
    return agent ? canPermissionRulesPrompt(agent.permission) : true;
};

export const togglePermissionAutoAccept = (args: PermissionAutoAcceptToggleArgs): void => {
    const {
        permissionScopeSessionId,
        newSessionDraftOpen,
        draftPermissionAutoAcceptEnabled,
        permissionAutoAcceptEnabled,
        setDraftPermissionAutoAcceptEnabled,
        setSessionAutoAccept,
        onOpenSessionFirst,
        onToggleFailed,
    } = args;

    if (!permissionScopeSessionId) {
        if (!newSessionDraftOpen) {
            onOpenSessionFirst();
            return;
        }

        setDraftPermissionAutoAcceptEnabled(!draftPermissionAutoAcceptEnabled);
        return;
    }

    const nextEnabled = !permissionAutoAcceptEnabled;
    void setSessionAutoAccept(permissionScopeSessionId, nextEnabled).catch(onToggleFailed);
};
