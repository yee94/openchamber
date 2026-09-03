import 'package:flutter/material.dart';

import '../../data/prompt_attachment.dart';
import '../../l10n/app_strings.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import 'composer_occupancy.dart';

/// Native composer chrome. Android is a floating pill with solid IME viewInsets.
/// iOS uses the UIKit platform view (`IosComposerHost`) instead of this widget.
class ComposerBar extends StatelessWidget {
  const ComposerBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.onDictate,
    this.onStop,
    this.busy = false,
    this.dictationLabel,
    this.attachments = const [],
    this.onRemoveAttachment,
    this.showScrollToBottom = false,
    this.onScrollToBottom,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onDictate;
  final VoidCallback? onStop;
  final String? dictationLabel;
  final bool busy;
  final List<AttachmentDraft> attachments;
  final ValueChanged<int>? onRemoveAttachment;
  final bool showScrollToBottom;
  final VoidCallback? onScrollToBottom;

  @override
  Widget build(BuildContext context) {
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
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
    );

    return SafeArea(
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
          if (dictationLabel != null)
            Padding(
              key: const Key('composer-dictate-status'),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(dictationLabel!, style: const TextStyle(fontSize: 12, color: OcChrome.secondary)),
            ),
          if (showScrollToBottom)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 22, bottom: 6),
                child: Material(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    key: const Key('chat-scroll-to-bottom'),
                    customBorder: const CircleBorder(),
                    onTap: onScrollToBottom,
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(child: OcGlyph(OcGlyphKind.chevronDown, size: 18)),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Material(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(OcChrome.pillRadius),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('composer-attach'),
                      tooltip: t(context, 'chat.composer.attach'),
                      onPressed: onAttach,
                      icon: const OcGlyph(OcGlyphKind.plus, size: 22),
                    ),
                    Expanded(child: field),
                    if (onDictate != null)
                      IconButton(
                        key: const Key('composer-dictate'),
                        tooltip: t(context, 'chat.dictation.start'),
                        onPressed: onDictate,
                        icon: const OcGlyph(OcGlyphKind.mic, size: 18),
                      ),
                    Material(
                      color: Colors.black,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: const Key('composer-send'),
                        customBorder: const CircleBorder(),
                        onTap: busy ? onStop : onSend,
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: Center(
                            child: OcGlyph(
                              OcGlyphKind.sendSquare,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
