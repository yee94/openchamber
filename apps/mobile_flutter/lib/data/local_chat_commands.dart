/// Cap `localCommandClassifier.ts` + `commandSelection.ts`.
/// Immediate `/compact` `/undo` `/redo` never `prompt_async`. `/model` opens the picker.
const localChatCommands = {
  'new',
  'fork',
  'compact',
  'undo',
  'redo',
  'timeline',
  'model',
  'summary',
  'workspace-review',
  'handoff-review',
  'goal',
  'craft-goal',
  'catch-up',
  'debug',
  'weigh',
  'explore',
};

const immediateLocalChatCommands = {'new', 'compact', 'fork', 'undo', 'redo'};

const autoSubmitSlashCommands = {'new', 'fork', 'compact', 'undo', 'redo', 'model', 'goal'};

final _slashCommandHead = RegExp(r'^/\u2003?([^\s]+)', caseSensitive: false);

String? getLocalChatCommand(String text) {
  final command = _slashCommandHead.firstMatch(text.trimLeft())?.group(1)?.toLowerCase();
  return command != null && localChatCommands.contains(command) ? command : null;
}

bool consumesImmediateCommandText(String text) {
  final command = getLocalChatCommand(text);
  return command != null && immediateLocalChatCommands.contains(command);
}

bool isModelSlashCommand(String text) {
  return getLocalChatCommand(text) == 'model';
}

bool shouldSubmitCommandOnSelection(String label) {
  final name = label.trim().replaceFirst(RegExp(r'^/'), '').split(RegExp(r'\s')).first.toLowerCase();
  return autoSubmitSlashCommands.contains(name);
}
