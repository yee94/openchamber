import 'package:flutter/material.dart';

import '../../data/prompt_attachment.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import 'composer_occupancy.dart';

/// Native composer chrome. Android / WidgetTester paint a frosted pill
/// (`BackdropFilter`). iOS uses the UIKit platform view (`IosComposerHost`).
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final suggestions = autocompleteStubFor(controller.text);
    final sendReady = !busy &&
        (controller.text.trim().isNotEmpty || attachments.isNotEmpty);
    final field = TextField(
      key: const Key('composer-field'),
      controller: controller,
      minLines: 1,
      maxLines: 6,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onSend(),
      style: TextStyle(
        fontSize: OcTokens.textMarkdown,
        letterSpacing: OcOptical.chatBodyTracking,
        height: OcOptical.chatBodyHeight,
        color: context.oc.foreground,
      ),
      decoration: InputDecoration(
        hintText: t(context, 'chat.composer.placeholder'),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: OcOptical.composerFieldPadV,
        ),
        hintStyle: TextStyle(
          fontSize: OcTokens.textMarkdown,
          letterSpacing: OcOptical.chatBodyTracking,
          height: OcOptical.chatBodyHeight,
          color: context.oc.mutedForeground,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
    );

    final view = MediaQuery.viewPaddingOf(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = inset > 0 ? 0.0 : view.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSafe),
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
                    shape: BoxShape.circle,
                    color: context.oc.background.withValues(alpha: 0.95),
                    boxShadow: OcElevation.chip(context),
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
                        child: OcGlyph(
                          OcGlyphKind.chevronDown,
                          size: OcOptical.scrollChevron,
                          strokeWidth: OcOptical.scrollChevronStroke,
                          color: context.oc.foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(OcOptical.composerRadius),
              // Official `.oc-mobile-composer-surface` is `--surface-subtle`
              // with `box-shadow: none` / `filter: none`. Frost + float
              // elevation read as a WidgetTester foot bar.
              child: ColoredBox(
                color: context.oc.surfaceSubtle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, OcOptical.composerPillPadV, 8, OcOptical.composerPillPadV),
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
                              width: 36,
                              height: 36,
                              child: Center(
                                child: OcGlyph(
                                  OcGlyphKind.plus,
                                  size: OcOptical.composerPlus,
                                  strokeWidth: OcOptical.composerPlusStroke,
                                  color: context.oc.foreground,
                                ),
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
                            icon: OcGlyph(OcGlyphKind.mic, size: OcOptical.toolbarGlyph, strokeWidth: OcOptical.headerGlyphStroke, color: context.oc.mutedForeground),
                          ),
                        Pressable(
                          key: const Key('composer-send'),
                          haptic: HapticStrength.medium,
                          highlight: false,
                          onPressed: busy ? onStop : onSend,
                          child: SizedBox(
                            width: OcOptical.sendRing,
                            height: OcOptical.sendRing,
                            child: Center(
                              child: busy
                                  ? DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: context.oc.foreground,
                                      ),
                                      child: SizedBox(
                                        width: OcOptical.sendRingDisc,
                                        height: OcOptical.sendRingDisc,
                                        child: Center(
                                          child: Container(
                                            width: OcOptical.sendStop,
                                            height: OcOptical.sendStop,
                                            decoration: BoxDecoration(
                                              color: context.oc.background,
                                              borderRadius: BorderRadius.circular(OcOptical.sendStop * 0.2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : sendReady
                                      ? DecoratedBox(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: context.oc.foreground,
                                          ),
                                          child: SizedBox(
                                            width: OcOptical.sendRingDisc,
                                            height: OcOptical.sendRingDisc,
                                            child: Center(
                                              child: OcGlyph(
                                                OcGlyphKind.arrowUp,
                                                size: OcOptical.sendArrow,
                                                strokeWidth: OcOptical.dockGlyphStroke,
                                                color: context.oc.background,
                                              ),
                                            ),
                                          ),
                                        )
                                      : OcGlyph(
                                          OcGlyphKind.sendPlane,
                                          size: OcOptical.sendPlane,
                                          strokeWidth: OcOptical.headerGlyphStrokeVisual,
                                          color: context.oc.primary,
                                        ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
