import 'package:flutter/material.dart';

import '../../data/prompt_attachment.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        hintStyle: TextStyle(
          fontSize: OcTokens.textMarkdown,
          letterSpacing: OcOptical.chatBodyTracking,
          height: OcOptical.chatBodyHeight,
          color: context.oc.mutedForeground,
        ),
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
              child: Text(dictationLabel!, style: TextStyle(fontSize: OcTokens.textMicro, color: context.oc.mutedForeground)),
            ),
          if (showScrollToBottom)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 22, bottom: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.oc.card,
                    shape: BoxShape.circle,
                    boxShadow: OcElevation.control(context),
                  ),
                  child: Pressable(
                    key: const Key('chat-scroll-to-bottom'),
                    haptic: HapticStrength.light,
                    highlight: false,
                    onPressed: onScrollToBottom,
                    child: SizedBox(
                      width: OcOptical.scrollFab,
                      height: OcOptical.scrollFab,
                      child: Center(
                        child: OcGlyph(OcGlyphKind.chevronDown, size: OcOptical.scrollChevron, strokeWidth: OcOptical.listGlyphStroke, color: context.oc.foreground),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(OcOptical.composerRadius),
                boxShadow: OcElevation.composer(context),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Row(
                  children: [
                    Tooltip(
                      message: t(context, 'chat.composer.attach'),
                      child: Pressable(
                        key: const Key('composer-attach'),
                        haptic: HapticStrength.medium,
                        highlight: false,
                        onPressed: onAttach,
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: OcGlyph(OcGlyphKind.plus, size: OcOptical.composerPlus, strokeWidth: OcOptical.listGlyphStroke, color: context.oc.foreground),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: field),
                    if (onDictate != null)
                      IconButton(
                        key: const Key('composer-dictate'),
                        tooltip: t(context, 'chat.dictation.start'),
                        visualDensity: VisualDensity.compact,
                        onPressed: onDictate,
                        icon: OcGlyph(OcGlyphKind.mic, size: OcOptical.toolbarGlyph, strokeWidth: OcOptical.listGlyphStroke, color: context.oc.mutedForeground),
                      ),
                    Pressable(
                      key: const Key('composer-send'),
                      haptic: HapticStrength.medium,
                      highlight: false,
                      onPressed: busy ? onStop : onSend,
                      child: Container(
                        width: OcOptical.sendRing,
                        height: OcOptical.sendRing,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.oc.foreground, width: OcOptical.sendRingStroke),
                        ),
                        child: busy
                            ? Container(
                                width: OcOptical.sendStop,
                                height: OcOptical.sendStop,
                                decoration: BoxDecoration(
                                  color: context.oc.foreground,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              )
                            : const SizedBox.shrink(),
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
