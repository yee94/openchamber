import 'package:flutter/material.dart';

import '../../data/chat_timeline.dart';
import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';

class ChatTranscriptBody extends StatelessWidget {
  const ChatTranscriptBody({
    super.key,
    required this.message,
    this.onPermission,
  });

  final ChatMessage message;
  final void Function(String requestId, String reply)? onPermission;

  @override
  Widget build(BuildContext context) {
    final cards = message.parts.where((part) => part.kind != ChatPartKind.text).toList();
    final text = message.body.trim();
    return Column(
      crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty) Text(text),
        if (message.tokensPerSecond != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              message.tokensPerSecond!,
              key: Key('chat-tps-${message.id}'),
              style: TextStyle(color: OcTokens.mutedLight, fontSize: 12),
            ),
          ),
        for (final part in cards)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ToolPartCard(part: part, onPermission: onPermission),
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
          child: _DiffPreview(part: part),
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
        return _CardShell(
          key: Key('chat-tool-permission-${part.id}'),
          title: t(context, 'chat.permission.title'),
          subtitle: [part.title, part.subtitle].whereType<String>().where((item) => item.isNotEmpty).join(' · '),
          child: Wrap(
            spacing: 8,
            children: [
              _ReplyButton(
                id: 'once',
                label: t(context, 'chat.permission.once'),
                onTap: () => onPermission?.call(part.permissionId ?? part.id, 'once'),
              ),
              _ReplyButton(
                id: 'always',
                label: t(context, 'chat.permission.always'),
                onTap: () => onPermission?.call(part.permissionId ?? part.id, 'always'),
              ),
              _ReplyButton(
                id: 'reject',
                label: t(context, 'chat.permission.reject'),
                onTap: () => onPermission?.call(part.permissionId ?? part.id, 'reject'),
              ),
            ],
          ),
        );
      case ChatPartKind.tool:
        return _CardShell(
          key: Key('chat-tool-row-${part.id}'),
          title: part.title,
          subtitle: part.status ?? part.toolName,
          child: part.body == null ? null : Text(part.body!, maxLines: 6, overflow: TextOverflow.ellipsis),
        );
      case ChatPartKind.text:
        return const SizedBox.shrink();
    }
  }
}

class _DiffPreview extends StatelessWidget {
  const _DiffPreview({required this.part});

  final ChatPart part;

  @override
  Widget build(BuildContext context) {
    final lines = [
      ...part.removed.take(6).map((line) => ('-', line)),
      ...part.added.take(6).map((line) => ('+', line)),
    ];
    if (lines.isEmpty && part.body != null) {
      return Text(part.body!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Text(
            '${line.$1} ${line.$2}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: line.$1 == '+'
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({super.key, required this.title, this.subtitle, this.child});

  final String title;
  final String? subtitle;
  final Widget? child;

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
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
  const _ReplyButton({required this.id, required this.label, required this.onTap});

  final String id;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: Key('chat-permission-$id'),
      onPressed: onTap,
      child: Text(label),
    );
  }
}
