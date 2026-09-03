import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/prompt_attachment.dart';
import '../../l10n/app_strings.dart';
import 'composer_occupancy.dart';

/// Native composer chrome. Android is Material 3 with solid IME viewInsets.
/// iOS uses the UIKit platform view (`IosComposerHost`) instead of this widget.
class ComposerBar extends StatelessWidget {
  const ComposerBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.onStop,
    this.busy = false,
    this.attachments = const [],
    this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onStop;
  final bool busy;
  final List<AttachmentDraft> attachments;
  final ValueChanged<int>? onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final suggestions = autocompleteStubFor(controller.text);
    final field = TextField(
      key: const Key('composer-field'),
      controller: controller,
      minLines: 1,
      maxLines: 6,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onSend(),
      decoration: InputDecoration(
        hintText: t(context, 'chat.composer.placeholder'),
        border: InputBorder.none,
      ),
    );

    final attach = IconButton(
      key: const Key('composer-attach'),
      tooltip: t(context, 'chat.composer.attach'),
      onPressed: onAttach,
      icon: Icon(ios ? CupertinoIcons.add : Icons.add),
    );
    final send = IconButton(
      key: const Key('composer-send'),
      tooltip: t(context, busy ? 'chat.composer.stop' : 'chat.composer.send'),
      onPressed: busy ? onStop : onSend,
      icon: Icon(
        busy
            ? (ios ? CupertinoIcons.stop_circle_fill : Icons.stop_circle)
            : (ios ? CupertinoIcons.arrow_up_circle_fill : Icons.send),
      ),
    );

    return Material(
      elevation: ios ? 0 : 2,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (suggestions.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView(
                  key: const Key('composer-autocomplete'),
                  children: [
                    for (final item in suggestions)
                      ListTile(
                        dense: true,
                        title: Text(item.label),
                        onTap: () => controller.text = item.label,
                      ),
                  ],
                ),
              ),
            if (attachments.isNotEmpty)
              SizedBox(
                height: 56,
                child: ListView.separated(
                  key: const Key('composer-attachments'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  itemCount: attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = attachments[index];
                    return InputChip(
                      key: Key('composer-attachment-${item.name}'),
                      label: Text(item.name),
                      avatar: Image.memory(item.bytes, width: 20, height: 20, fit: BoxFit.cover),
                      onDeleted: onRemoveAttachment == null ? null : () => onRemoveAttachment!(index),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  attach,
                  Expanded(child: field),
                  send,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
