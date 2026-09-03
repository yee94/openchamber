import 'package:flutter/material.dart';

import '../../data/chat_timeline.dart';
import '../../data/context_tool_grouping.dart';
import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';

class ChatTranscriptBody extends StatelessWidget {
  const ChatTranscriptBody({
    super.key,
    required this.message,
    this.onPermission,
    this.isLastAssistant = false,
    this.isTurnLive = false,
  });

  final ChatMessage message;
  final void Function(String requestId, String reply)? onPermission;
  final bool isLastAssistant;
  final bool isTurnLive;

  @override
  Widget build(BuildContext context) {
    final activityActive = isTurnLive || messageHasRunningTool(message);
    final hasActivityParts = message.parts.any(_isActivityPart);
    final defaultExpanded = activityActive ||
        (isLastAssistant && !messageHasConfirmedFinalBody(message));
    final children = <Widget>[
      if (hasActivityParts && !message.isUser)
        _ActivityDisclosure(
          messageId: message.id,
          active: activityActive,
          initiallyExpanded: defaultExpanded,
          child: _ActivityItems(
            parts: message.parts,
            isTurnLive: isTurnLive,
            onPermission: onPermission,
          ),
        ),
      ..._alwaysVisible(context),
    ];
    return Column(
      crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: children,
    );
  }

  List<Widget> _alwaysVisible(BuildContext context) {
    final out = <Widget>[];
    for (final part in message.parts) {
      if (part.kind == ChatPartKind.text && (part.body ?? '').trim().isNotEmpty) {
        out.add(Text(part.body!.trim()));
      } else if (part.kind == ChatPartKind.mermaid) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _MermaidCard(part: part),
        ));
      } else if (part.kind == ChatPartKind.permission) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _PermissionCard(part: part, onPermission: onPermission),
        ));
      }
    }
    if (message.tokensPerSecond != null) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            message.tokensPerSecond!,
            key: Key('chat-tps-${message.id}'),
            style: TextStyle(color: OcTokens.mutedLight, fontSize: 12),
          ),
        ),
      );
    }
    return out;
  }
}

bool _isActivityPart(ChatPart part) =>
    part.kind == ChatPartKind.diff ||
    part.kind == ChatPartKind.fileOp ||
    part.kind == ChatPartKind.task ||
    part.kind == ChatPartKind.tool;

class _ActivityItems extends StatelessWidget {
  const _ActivityItems({
    required this.parts,
    required this.isTurnLive,
    this.onPermission,
  });

  final List<ChatPart> parts;
  final bool isTurnLive;
  final void Function(String requestId, String reply)? onPermission;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var index = 0;
    while (index < parts.length) {
      final part = parts[index];
      if (!_isActivityPart(part)) {
        index += 1;
        continue;
      }
      if (isContextGroupTool(part.toolName)) {
        final grouped = collectConsecutiveContextTools(parts, index);
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _ContextToolGroup(
              parts: grouped.items,
              exploring: isContextGroupExploring(
                parts: grouped.items,
                hasFollowingOtherType: hasContextExploreSuccessor(parts, grouped.end),
                isTurnLive: isTurnLive,
              ),
            ),
          ),
        );
        index = grouped.end;
        continue;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ToolPartCard(part: part, onPermission: onPermission),
        ),
      );
      index += 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _ActivityDisclosure extends StatefulWidget {
  const _ActivityDisclosure({
    required this.messageId,
    required this.active,
    required this.initiallyExpanded,
    required this.child,
  });

  final String messageId;
  final bool active;
  final bool initiallyExpanded;
  final Widget child;

  @override
  State<_ActivityDisclosure> createState() => _ActivityDisclosureState();
}

class _ActivityDisclosureState extends State<_ActivityDisclosure> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(_ActivityDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_expanded) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockedOpen = widget.active;
    final open = lockedOpen || _expanded;
    final status = widget.active
        ? t(context, 'chat.activity.active')
        : t(context, 'chat.activity.completedStatus');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: Key('chat-activity-${widget.messageId}'),
          onTap: lockedOpen
              ? null
              : () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.layers_outlined, size: 16, color: OcTokens.mutedLight),
                const SizedBox(width: 6),
                Text(
                  status,
                  key: Key('chat-activity-status-${widget.messageId}'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OcTokens.mutedLight,
                  ),
                ),
                const Spacer(),
                if (!lockedOpen)
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: OcTokens.mutedLight,
                    semanticLabel: t(
                      context,
                      open ? 'chat.activity.collapseAria' : 'chat.activity.expandAria',
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (open) widget.child,
      ],
    );
  }
}

class _ContextToolGroup extends StatefulWidget {
  const _ContextToolGroup({required this.parts, required this.exploring});

  final List<ChatPart> parts;
  final bool exploring;

  @override
  State<_ContextToolGroup> createState() => _ContextToolGroupState();
}

class _ContextToolGroupState extends State<_ContextToolGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final counts = summarizeContextTools(widget.parts.map((part) => part.toolName));
    final summary = contextToolCountOrder
        .where((key) => counts[key] > 0)
        .map((key) {
          final count = counts[key];
          switch (key) {
            case ContextToolCountKey.search:
              return t(
                context,
                count == 1 ? 'chat.contextGroup.searchSingle' : 'chat.contextGroup.searchPlural',
                {'count': '$count'},
              );
            case ContextToolCountKey.read:
              return t(
                context,
                count == 1 ? 'chat.contextGroup.readSingle' : 'chat.contextGroup.readPlural',
                {'count': '$count'},
              );
            case ContextToolCountKey.list:
              return t(
                context,
                count == 1 ? 'chat.contextGroup.listSingle' : 'chat.contextGroup.listPlural',
                {'count': '$count'},
              );
          }
        })
        .join(', ');
    final title = t(
      context,
      widget.exploring ? 'chat.contextGroup.exploring' : 'chat.contextGroup.explored',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: Key('chat-context-group-${widget.parts.first.id}'),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Icon(
                widget.exploring ? Icons.travel_explore : Icons.search,
                size: 16,
                color: OcTokens.mutedLight,
              ),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (summary.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary,
                    key: Key('chat-context-summary-${widget.parts.first.id}'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: OcTokens.mutedLight, fontSize: 12),
                  ),
                ),
              ],
              Icon(_expanded ? Icons.expand_more : Icons.chevron_right, size: 16, color: OcTokens.mutedLight),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final part in widget.parts)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ToolPartCard(part: part),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class ToolPartCard extends StatelessWidget {
  const ToolPartCard({super.key, required this.part, this.onPermission});

  final ChatPart part;
  final void Function(String requestId, String reply)? onPermission;

  @override
  Widget build(BuildContext context) {
    switch (part.kind) {
      case ChatPartKind.diff:
        return _CardShell(
          key: Key('chat-tool-diff-${part.id}'),
          title: part.title,
          subtitle: part.status,
          trailing: null,
          child: _DiffViewer(part: part),
        );
      case ChatPartKind.fileOp:
        return _CardShell(
          key: Key('chat-tool-file-${part.id}'),
          title: part.title,
          subtitle: part.path ?? part.status,
          child: part.body == null ? null : Text(part.body!, maxLines: 4, overflow: TextOverflow.ellipsis),
        );
      case ChatPartKind.task:
        return _CardShell(
          key: Key('chat-tool-task-${part.id}'),
          title: part.title,
          subtitle: [
            if (part.status != null) part.status,
            if (part.tokensPerSecond != null) part.tokensPerSecond,
          ].whereType<String>().join(' · '),
          child: part.body == null ? null : Text(part.body!),
        );
      case ChatPartKind.permission:
        return _PermissionCard(part: part, onPermission: onPermission);
      case ChatPartKind.tool:
        return _CardShell(
          key: Key('chat-tool-row-${part.id}'),
          title: part.title,
          subtitle: part.status ?? part.toolName,
          child: part.body == null ? null : Text(part.body!, maxLines: 6, overflow: TextOverflow.ellipsis),
        );
      case ChatPartKind.mermaid:
        return _MermaidCard(part: part);
      case ChatPartKind.text:
        return const SizedBox.shrink();
    }
  }
}

class _DiffViewer extends StatefulWidget {
  const _DiffViewer({required this.part});

  final ChatPart part;

  @override
  State<_DiffViewer> createState() => _DiffViewerState();
}

class _DiffViewerState extends State<_DiffViewer> {
  /// Official ToolPart default is unified (`DiffViewMode = 'unified'`).
  bool _sideBySide = false;

  static const _maxLines = 200;

  @override
  Widget build(BuildContext context) {
    final lines = widget.part.diffLines.isNotEmpty
        ? widget.part.diffLines
        : [
            ...widget.part.removed.map((line) => DiffLine(kind: 'remove', text: line)),
            ...widget.part.added.map((line) => DiffLine(kind: 'add', text: line)),
          ];
    final visible = lines.take(_maxLines).toList();
    final hidden = lines.length - visible.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            key: Key('chat-diff-toggle-${widget.part.id}'),
            tooltip: t(
              context,
              _sideBySide ? 'chat.diff.switchToUnified' : 'chat.diff.switchToSideBySide',
            ),
            visualDensity: VisualDensity.compact,
            icon: Icon(_sideBySide ? Icons.view_headline : Icons.view_column, size: 16),
            onPressed: () => setState(() => _sideBySide = !_sideBySide),
          ),
        ),
        if (_sideBySide) _SideBySideDiff(lines: visible) else _UnifiedDiff(lines: visible),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              t(context, 'chat.diff.moreLines', {'count': '$hidden'}),
              style: TextStyle(color: OcTokens.mutedLight, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _UnifiedDiff extends StatelessWidget {
  const _UnifiedDiff({required this.lines});

  final List<DiffLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Text(
            '${_prefix(line.kind)} ${line.text}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: _diffColor(context, line.kind),
            ),
          ),
      ],
    );
  }
}

class _SideBySideDiff extends StatelessWidget {
  const _SideBySideDiff({required this.lines});

  final List<DiffLine> lines;

  @override
  Widget build(BuildContext context) {
    final rows = _pairSideBySide(lines);
    return Column(
      children: [
        for (final row in rows)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  row.$1 == null ? '' : '- ${row.$1}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: row.$1 == null ? OcTokens.mutedLight : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.$2 == null ? '' : '+ ${row.$2}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: row.$2 == null ? OcTokens.mutedLight : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

List<(String?, String?)> _pairSideBySide(List<DiffLine> lines) {
  final rows = <(String?, String?)>[];
  final removed = <String>[];
  final added = <String>[];
  void flushChanges() {
    final count = removed.length > added.length ? removed.length : added.length;
    for (var i = 0; i < count; i += 1) {
      rows.add((
        i < removed.length ? removed[i] : null,
        i < added.length ? added[i] : null,
      ));
    }
    removed.clear();
    added.clear();
  }

  for (final line in lines) {
    if (line.kind == 'context') {
      flushChanges();
      rows.add((line.text, line.text));
      continue;
    }
    if (line.kind == 'remove') {
      removed.add(line.text);
      continue;
    }
    if (line.kind == 'add') {
      added.add(line.text);
    }
  }
  flushChanges();
  return rows;
}

String _prefix(String kind) {
  if (kind == 'add') return '+';
  if (kind == 'remove') return '-';
  return ' ';
}

Color _diffColor(BuildContext context, String kind) {
  if (kind == 'add') return Theme.of(context).colorScheme.primary;
  if (kind == 'remove') return Theme.of(context).colorScheme.error;
  return OcTokens.mutedLight;
}

class _MermaidCard extends StatelessWidget {
  const _MermaidCard({required this.part});

  final ChatPart part;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      key: Key('chat-mermaid-${part.id}'),
      title: t(context, 'chat.mermaid.title'),
      subtitle: t(context, 'chat.mermaid.sourceOnly'),
      child: Text(
        part.body ?? '',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.part, this.onPermission});

  final ChatPart part;
  final void Function(String requestId, String reply)? onPermission;

  @override
  Widget build(BuildContext context) {
    final tool = (part.toolName ?? part.title).toLowerCase();
    return DecoratedBox(
      key: Key('chat-tool-permission-${part.id}'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: Theme.of(context).colorScheme.tertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t(context, 'sessions.sidebar.session.status.permissionRequired'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: OcTokens.mutedLight),
                  ),
                ),
                Text(
                  _permissionToolLabel(tool),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: OcTokens.mutedLight),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (part.patterns.isNotEmpty) ...[
                  Text(t(context, 'chat.permissionCard.patterns'), style: TextStyle(color: OcTokens.mutedLight, fontSize: 11)),
                  const SizedBox(height: 4),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < part.patterns.length; i += 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Text(part.patterns[i], style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ..._permissionBody(context, tool, part.metadata),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: _ReplyButton(
                    id: 'once',
                    label: t(context, 'chat.permissionCard.allowOnce'),
                    onTap: () => onPermission?.call(part.permissionId ?? part.id, 'once'),
                  ),
                ),
                Expanded(
                  child: _ReplyButton(
                    id: 'always',
                    label: t(context, 'chat.permissionCard.alwaysAgree'),
                    onTap: () => onPermission?.call(part.permissionId ?? part.id, 'always'),
                  ),
                ),
                Expanded(
                  child: _ReplyButton(
                    id: 'reject',
                    label: t(context, 'chat.permissionToast.actions.deny'),
                    destructive: true,
                    onTap: () => onPermission?.call(part.permissionId ?? part.id, 'reject'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _permissionBody(BuildContext context, String tool, Map<String, Object?> metadata) {
  String meta(List<String> keys) {
    for (final key in keys) {
      final value = metadata[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }
    return '';
  }

  if (tool == 'bash' || tool == 'shell' || tool == 'shell_command') {
    final command = meta(['command', 'cmd', 'script']);
    final cwd = meta(['cwd', 'working_directory', 'directory', 'path']);
    return [
      if (cwd.isNotEmpty)
        Text('${t(context, 'chat.permissionCard.workingDirectory')} $cwd', style: TextStyle(color: OcTokens.mutedLight, fontSize: 12)),
      if (command.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(command, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
    ];
  }
  if (tool == 'edit' || tool == 'multiedit' || tool == 'str_replace' || tool == 'str_replace_based_edit_tool') {
    final changes = meta(['changes', 'diff']);
    if (changes.isEmpty) return const [];
    final diff = parsePermissionDiff(changes);
    return [_UnifiedDiff(lines: diff)];
  }
  if (tool == 'write' || tool == 'create' || tool == 'file_write') {
    final content = meta(['content', 'text', 'data']);
    if (content.isEmpty) return const [];
    return [
      Text(content, maxLines: 8, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
    ];
  }
  if (tool == 'webfetch' || tool == 'fetch' || tool == 'curl' || tool == 'wget') {
    final url = meta(['url', 'uri', 'endpoint']);
    final method = meta(['method']).isEmpty ? 'GET' : meta(['method']);
    return [
      Text(t(context, 'chat.permissionCard.request'), style: TextStyle(color: OcTokens.mutedLight, fontSize: 11)),
      if (url.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('$method $url', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
    ];
  }
  if (metadata.isEmpty) return const [];
  final details = metadata.entries
      .where((entry) => entry.key != 'always' && entry.value != null)
      .map((entry) => '${entry.key}: ${entry.value}')
      .join('\n');
  if (details.isEmpty) return const [];
  return [
    Text(t(context, 'chat.permissionCard.details'), style: TextStyle(color: OcTokens.mutedLight, fontSize: 11)),
    Text(details, maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
  ];
}

List<DiffLine> parsePermissionDiff(String raw) {
  if (raw.contains('\n') && (raw.contains('\n+') || raw.contains('\n-') || raw.startsWith('+') || raw.startsWith('-'))) {
    return [
      for (final line in raw.replaceAll('\r\n', '\n').split('\n'))
        if (line.startsWith('+') && !line.startsWith('+++'))
          DiffLine(kind: 'add', text: line.substring(1))
        else if (line.startsWith('-') && !line.startsWith('---'))
          DiffLine(kind: 'remove', text: line.substring(1))
        else if (!line.startsWith('@@') && !line.startsWith('diff ') && !line.startsWith('+++') && !line.startsWith('---'))
          DiffLine(kind: 'context', text: line.startsWith(' ') ? line.substring(1) : line),
    ];
  }
  return [DiffLine(kind: 'context', text: raw)];
}

String _permissionToolLabel(String tool) {
  if (tool == 'edit' || tool == 'multiedit' || tool == 'str_replace' || tool == 'str_replace_based_edit_tool') {
    return 'edit';
  }
  if (tool == 'write' || tool == 'create' || tool == 'file_write') return 'write';
  if (tool == 'bash' || tool == 'shell' || tool == 'cmd' || tool == 'terminal' || tool == 'shell_command') {
    return 'bash';
  }
  if (tool == 'webfetch' || tool == 'fetch' || tool == 'curl' || tool == 'wget') return 'webfetch';
  return tool;
}

class _CardShell extends StatelessWidget {
  const _CardShell({super.key, required this.title, this.subtitle, this.child, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, style: TextStyle(color: OcTokens.mutedLight, fontSize: 12)),
              ),
            if (child != null) Padding(padding: const EdgeInsets.only(top: 8), child: child),
          ],
        ),
      ),
    );
  }
}

class _ReplyButton extends StatelessWidget {
  const _ReplyButton({
    required this.id,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String id;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface;
    return TextButton(
      key: Key('chat-permission-$id'),
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: color,
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
    );
  }
}
