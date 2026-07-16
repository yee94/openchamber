const isPermissionAction = (value) => value === 'allow' || value === 'ask' || value === 'deny';

/** Normalize OpenCode permission config / ruleset into a flat rule list. */
export const normalizePermissionRules = (value) => {
  if (isPermissionAction(value)) {
    return [{ permission: '*', pattern: '*', action: value }];
  }

  if (Array.isArray(value)) {
    const rules = [];
    for (const entry of value) {
      if (!entry || typeof entry !== 'object') continue;
      if (
        typeof entry.permission !== 'string'
        || typeof entry.pattern !== 'string'
        || !isPermissionAction(entry.action)
      ) {
        continue;
      }
      rules.push({
        permission: entry.permission,
        pattern: entry.pattern,
        action: entry.action,
      });
    }
    return rules;
  }

  if (!value || typeof value !== 'object') return [];

  const rules = [];
  for (const [permissionName, configValue] of Object.entries(value)) {
    if (permissionName === '__originalKeys') continue;
    if (isPermissionAction(configValue)) {
      rules.push({ permission: permissionName, pattern: '*', action: configValue });
      continue;
    }
    if (configValue && typeof configValue === 'object' && !Array.isArray(configValue)) {
      for (const [pattern, action] of Object.entries(configValue)) {
        if (isPermissionAction(action)) {
          rules.push({ permission: permissionName, pattern, action });
        }
      }
    }
  }
  return rules;
};

/**
 * True when the policy is globally open: `allow` / `{ "*": "allow" }` (or ruleset
 * equivalent) and contains no `ask` rules. Deny-only overrides do not create prompts.
 */
export const isFullyAllowPermissionPolicy = (permission) => {
  const rules = normalizePermissionRules(permission);
  if (rules.length === 0) return false;
  if (rules.some((rule) => rule.action === 'ask')) return false;
  return rules.some(
    (rule) => rule.permission === '*' && rule.pattern === '*' && rule.action === 'allow',
  );
};

const canRulesPrompt = (permission) => {
  const rules = normalizePermissionRules(permission);
  for (let index = rules.length - 1; index >= 0; index -= 1) {
    const rule = rules[index];
    if (rule.permission === '*' && rule.pattern === '*') return rule.action === 'ask';
    if (rule.action === 'ask') return true;
  }
  return false;
};

/**
 * Whether the composer should show the session permission auto-accept control.
 * Fail open: show unless we positively know nothing can prompt.
 */
export const shouldShowPermissionAutoAcceptControl = (input = {}) => {
  if (!isFullyAllowPermissionPolicy(input.configPermission)) return true;
  if ((input.agents ?? []).some((agent) => canRulesPrompt(agent?.permission))) return true;
  return false;
};
