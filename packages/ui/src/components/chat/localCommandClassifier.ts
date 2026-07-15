export const LOCAL_CHAT_COMMANDS = new Set([
  'new', 'fork', 'compact', 'undo', 'redo', 'timeline', 'model', 'summary', 'workspace-review', 'handoff-review', 'plan-feature', 'goal', 'craft-goal', 'catch-up', 'debug', 'weigh', 'explore',
]);

export const IMMEDIATE_LOCAL_CHAT_COMMANDS = new Set([
  'compact', 'fork', 'undo', 'redo',
]);

export const getLocalChatCommand = (text: string, inputMode: 'normal' | 'shell'): string | null => {
  if (inputMode !== 'normal') return null;
  const command = text.trimStart().match(/^\/([^\s]+)/)?.[1]?.toLowerCase();
  return command && LOCAL_CHAT_COMMANDS.has(command) ? command : null;
};

export const preservesComposerResources = (text: string, inputMode: 'normal' | 'shell'): boolean => (
  getLocalChatCommand(text, inputMode) !== null
);

export const consumesImmediateCommandText = (text: string, inputMode: 'normal' | 'shell'): boolean => {
  const command = getLocalChatCommand(text, inputMode);
  return command !== null && IMMEDIATE_LOCAL_CHAT_COMMANDS.has(command);
};
