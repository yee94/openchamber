import 'package:flutter/material.dart';

import '../../data/chat_timeline.dart';
import '../../data/context_tool_grouping.dart';
import '../../data/file_preview.dart';
import '../../data/generated_result.dart';
import '../../data/skill_tool_grouping.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import '../files/file_preview_scope.dart';
import 'chat_markdown_body.dart';
import 'reasoning_block.dart';

class ChatTranscriptBody extends StatelessWidget {
  const ChatTranscriptBody({
    super.key,
    required this.message,
    this.onPermission,
    this.onCopy,
    this.onShare,
    this.onFork,
    this.isLastAssistant = false,
    this.isTurnLive = false,
    this.isStreaming = false,
  });

  final ChatMessage message;
  final void Function(String requestId, String reply)? onPermission;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final VoidCallback? onFork;
  final bool isLastAssistant;
  final bool isTurnLive;
  /// Busy last-assistant turn. Independent of a running tool so text-only
  /// SSE tokens still debounce Markdown and auto-expand live reasoning.
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final activityActive = isTurnLive || messageHasRunningTool(message);
    final hasActivityParts = message.parts.any(_isActivityPart);
    final defaultExpanded = activityActive ||
        (isLastAssistant && !messageHasConfirmedFinalBody(message));
    final children = <Widget>[
      if (!message.isUser) _AssistantHeader(message: message),
      if (hasActivityParts && !message.isUser)
        _ActivityDisclosure(
          messageId: message.id,
          active: activityActive,
          initiallyExpanded: defaultExpanded,
          processedLabel: message.processedLabel,
          agentCount: message.agentCount,
          child: _ActivityItems(
            parts: message.parts,
            isTurnLive: isTurnLive,
            onPermission: onPermission,
          ),
        ),
      ..._alwaysVisible(context),
    ];
    return DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: OcTokens.textMarkdown,
        height: OcOptical.chatBodyHeight,
        letterSpacing: OcOptical.chatBodyTracking,
        color: context.oc.foreground,
      ),
      child: Column(
        crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  List<Widget> _alwaysVisible(BuildContext context) {
    final out = <Widget>[];
    final textParts = message.parts
        .where((part) => part.kind == ChatPartKind.text && (part.body ?? '').trim().isNotEmpty)
        .toList();
    var textIndex = 0;
    var paintedText = false;
    for (final part in message.parts) {
      if (part.kind == ChatPartKind.reasoning) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ReasoningTraceBlock(
            key: ValueKey<String>('reasoning-widget-${part.id}'),
            part: part,
            isLive: isStreaming && part.status != 'completed',
          ),
        ));
      } else if (part.kind == ChatPartKind.text && (part.body ?? '').trim().isNotEmpty) {
        final generated = parseGeneratedJsonResult(part.body!.trim());
        if (generated != null) {
          out.add(Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _GeneratedResultCard(result: generated, partId: part.id),
          ));
          paintedText = true;
        } else if (message.isUser && textParts.length > 1 && textIndex == 0) {
          // Mention is transcript data, not chrome. README toolbar is clock + actions only.
        } else {
          out.add(
            _assistantNarrative(
              cacheKey: '${message.id}-${part.id}',
              text: part.body!.trim(),
              isLive: isStreaming && isLastAssistant,
            ),
          );
          paintedText = true;
        }
        textIndex += 1;
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
      } else if (_isImagePreviewPart(part)) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ToolPartCard(part: part),
        ));
      }
    }
    final diffs = message.parts.where((part) => part.kind == ChatPartKind.diff).toList();
    if (diffs.isNotEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _FileChangeCard(parts: diffs, keyRows: diffs.length > 1),
      ));
      if (diffs.length == 1) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ToolPartCard(part: diffs.single),
        ));
      }
    }
    if (!paintedText && message.body.trim().isNotEmpty) {
      out.add(
        _assistantNarrative(
          cacheKey: '${message.id}-body',
          text: message.body.trim(),
          isLive: isStreaming && isLastAssistant,
        ),
      );
    }
    if (message.errorKind == 'aborted') {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          t(context, 'chat.messageBody.aborted'),
          key: Key('chat-aborted-${message.id}'),
          style: TextStyle(color: OcTokens.of(context).mutedForeground, fontSize: OcTokens.textMeta),
        ),
      ));
    } else if (message.errorKind == 'error') {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          message.errorText ?? t(context, 'chat.error.loadFailed'),
          key: Key('chat-error-${message.id}'),
          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: OcTokens.textMeta),
        ),
      ));
    }
    if (!message.isUser) {
      out.add(_TurnFooter(message: message, onCopy: onCopy, onShare: onShare, onFork: onFork));
    }
    return out;
  }
}

/// Completed-activity narrative uses the green `pub` badge. Markdown
/// stays for every other assistant body so fences and emphasis survive.
Widget _assistantNarrative({
  required String cacheKey,
  required String text,
  required bool isLive,
}) {
  if (RegExp(r'\bpub\b').hasMatch(text)) {
    return _ActivityInkText(text);
  }
  return ChatMarkdownBody(
    cacheKey: cacheKey,
    text: text,
    isLive: isLive,
  );
}

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final name = message.modelName ?? t(context, 'app.name');
    final role = message.agentRole;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OcGlyph(
                OcGlyphKind.sparkles,
                size: 16,
                strokeWidth: OcOptical.listGlyphStroke,
                color: context.oc.mutedForeground,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: OcTokens.textUiHeader,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: context.oc.foreground,
                  ),
                ),
              ),
              if (role != null && role.isNotEmpty) ...[
                const SizedBox(width: 8),
                DecoratedBox(
                  key: const Key('chat-role-badge'),
                  decoration: BoxDecoration(
                    color: context.oc.muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    child: Text(
                      role,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                        color: context.oc.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (message.agentCount > 0 && message.processedLabel == null)
            Align(
              alignment: Alignment.centerRight,
              child: _AgentCountChip(count: message.agentCount),
            ),
        ],
      ),
    );
  }
}

class _AgentCountChip extends StatelessWidget {
  const _AgentCountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('chat-agent-count'),
      mainAxisSize: MainAxisSize.min,
      children: [
          OcGlyph(OcGlyphKind.sparkles, size: 8, strokeWidth: OcOptical.listGlyphStroke, color: context.oc.mutedForeground),
          const SizedBox(width: 3),
          Text(
            t(context, 'chat.agentsInvolved', {'count': '$count'}),
            style: TextStyle(fontSize: 10, color: context.oc.foreground, fontWeight: FontWeight.w500, height: 1.1),
          ),
          OcGlyph(OcGlyphKind.chevronRight, size: 9, color: context.oc.mutedForeground),
      ],
    );
  }
}

class _FileChangeCard extends StatelessWidget {
  const _FileChangeCard({required this.parts, this.keyRows = true});

  final List<ChatPart> parts;
  final bool keyRows;

  @override
  Widget build(BuildContext context) {
    final visible = parts.take(5).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.oc.muted.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(OcTokens.radius),
        border: Border.all(color: context.oc.foreground.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OcGlyph(OcGlyphKind.file, size: OcOptical.fileTypeSize, strokeWidth: OcOptical.fileTypeStrokeVisual, color: OcTokens.of(context).mutedForeground),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  t(context, 'chat.filesChanged.title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: OcOptical.fileChrome,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                t(context, 'chat.filesChanged.count', {'count': '${parts.length}'}),
                style: TextStyle(
                  fontSize: OcOptical.fileChrome,
                  height: 1,
                  color: OcTokens.of(context).mutedForeground,
                ),
              ),
              const SizedBox(width: 2),
              OcGlyph(OcGlyphKind.chevronRight, size: OcOptical.fileTypeSize, color: OcTokens.of(context).mutedForeground.withValues(alpha: 0.6)),
            ],
          ),
          for (final part in visible)
            Pressable(
              key: keyRows ? Key('chat-tool-diff-${part.id}') : null,
              haptic: HapticStrength.light,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: OcOptical.fileRowHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: OcOptical.fileRowPadV),
                  child: Row(
                    children: [
                      _FileTypeMark(path: part.path ?? part.title),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          part.path ?? part.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: OcOptical.fileChrome,
                            height: 1,
                          ),
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '+${part.added.length}',
                              style: TextStyle(color: OcTokens.of(context).statusSuccess),
                            ),
                            const TextSpan(text: '/'),
                            TextSpan(
                              text: '-${part.removed.length}',
                              style: TextStyle(color: OcTokens.of(context).destructive),
                            ),
                          ],
                        ),
                        key: Key('chat-file-slash-${part.id}'),
                        style: const TextStyle(
                          fontSize: OcOptical.fileChrome,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (parts.length > visible.length)
            Pressable(
              haptic: HapticStrength.light,
              child: Row(
                children: [
                  Text(
                    t(context, 'chat.filesChanged.more', {'count': '${parts.length - visible.length}'}),
                    style: TextStyle(
                      fontSize: OcOptical.fileChrome,
                      height: 1,
                      color: OcTokens.of(context).mutedForeground,
                    ),
                  ),
                  OcGlyph(OcGlyphKind.chevronRight, size: OcOptical.fileTypeSize, strokeWidth: OcOptical.fileTypeStrokeVisual, color: OcTokens.of(context).mutedForeground),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class UserTurnToolbar extends StatelessWidget {
  const UserTurnToolbar({
    super.key,
    required this.message,
    this.onCopy,
    this.onFork,
  });

  final ChatMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onFork;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.completedClock != null) ...[
            OcGlyph(OcGlyphKind.clock, size: OcOptical.footerGlyph, strokeWidth: OcOptical.footerGlyphStrokeVisual, color: context.oc.mutedForeground),
            const SizedBox(width: 3),
            Text(
              message.completedClock!,
              style: TextStyle(
                fontSize: OcOptical.meta,
                letterSpacing: OcOptical.metaTracking,
                height: OcOptical.metaHeight,
                color: context.oc.mutedForeground,
              ),
            ),
            const SizedBox(width: 6),
          ],
          _icon(context, key: const Key('chat-action-revert'), glyph: OcGlyphKind.undo, tooltip: t(context, 'chat.messageBody.actions.revert')),
          _icon(context, key: const Key('chat-action-edit'), glyph: OcGlyphKind.edit, tooltip: t(context, 'chat.messageBody.actions.edit')),
          _icon(context, key: const Key('chat-action-fork'), glyph: OcGlyphKind.branch, tooltip: t(context, 'chat.messageBody.actions.fork'), onTap: onFork),
          _icon(context, key: const Key('chat-action-link'), glyph: OcGlyphKind.link, tooltip: t(context, 'chat.messageBody.actions.copyMessage'), onTap: onCopy),
          _icon(context, key: const Key('chat-action-copy-user'), glyph: OcGlyphKind.copy, tooltip: t(context, 'chat.messageBody.actions.copyMessage'), onTap: onCopy),
        ],
      ),
    );
  }

  Widget _icon(
    BuildContext context, {
    required Key key,
    required OcGlyphKind glyph,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: OcGlyph(glyph, size: OcOptical.footerGlyph, strokeWidth: OcOptical.footerGlyphStrokeVisual, color: context.oc.mutedForeground),
        ),
      ),
    );
  }
}

/// Official mobile `FileTypeIcon` is `h-3` per-language silhouette
/// (seti), not one tinted document for every path.
enum _FileKind { markdown, react, script, dart, other }

class _FileTypeMark extends StatelessWidget {
  const _FileTypeMark({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final tokens = OcTokens.of(context);
    final lower = path.toLowerCase();
    final _FileKind kind;
    final Color tint;
    if (lower.endsWith('.md')) {
      kind = _FileKind.markdown;
      tint = tokens.chart1;
    } else if (lower.endsWith('.tsx') || lower.endsWith('.jsx')) {
      kind = _FileKind.react;
      tint = tokens.chart5;
    } else if (lower.endsWith('.ts') || lower.endsWith('.js')) {
      kind = _FileKind.script;
      tint = tokens.chart1;
    } else if (lower.endsWith('.dart')) {
      kind = _FileKind.dart;
      tint = tokens.chart4;
    } else {
      kind = _FileKind.other;
      tint = tokens.mutedForeground;
    }
    return CustomPaint(
      size: const Size.square(OcOptical.fileTypeSize),
      painter: _FileTypeSpritePainter(kind: kind, tint: tint),
    );
  }
}

class _FileTypeSpritePainter extends CustomPainter {
  const _FileTypeSpritePainter({required this.kind, required this.tint});

  final _FileKind kind;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = OcOptical.fileTypeStrokeVisual
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.butt;
    switch (kind) {
      case _FileKind.markdown:
        final file = Path()
          ..moveTo(w * 0.28, h * 0.12)
          ..lineTo(w * 0.60, h * 0.12)
          ..lineTo(w * 0.78, h * 0.30)
          ..lineTo(w * 0.78, h * 0.88)
          ..lineTo(w * 0.22, h * 0.88)
          ..lineTo(w * 0.22, h * 0.12)
          ..close();
        canvas.drawPath(file, stroke);
        canvas.drawLine(Offset(w * 0.60, h * 0.12), Offset(w * 0.60, h * 0.32), stroke);
        canvas.drawLine(Offset(w * 0.60, h * 0.32), Offset(w * 0.78, h * 0.32), stroke);
        canvas.drawLine(Offset(w * 0.38, h * 0.48), Offset(w * 0.50, h * 0.68), stroke);
        canvas.drawLine(Offset(w * 0.50, h * 0.68), Offset(w * 0.62, h * 0.48), stroke);
      case _FileKind.react:
        canvas.save();
        canvas.translate(w * 0.5, h * 0.5);
        canvas.drawCircle(Offset.zero, w * 0.07, stroke);
        for (var i = 0; i < 3; i++) {
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 0.78, height: h * 0.24), stroke);
          canvas.rotate(1.047);
        }
        canvas.restore();
      case _FileKind.script:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.18, h * 0.18, w * 0.64, h * 0.64),
            Radius.circular(w * 0.14),
          ),
          stroke,
        );
        canvas.drawLine(Offset(w * 0.34, h * 0.40), Offset(w * 0.50, h * 0.40), stroke);
        canvas.drawLine(Offset(w * 0.42, h * 0.40), Offset(w * 0.42, h * 0.64), stroke);
        canvas.drawLine(Offset(w * 0.54, h * 0.46), Offset(w * 0.68, h * 0.46), stroke);
        canvas.drawLine(Offset(w * 0.54, h * 0.56), Offset(w * 0.66, h * 0.56), stroke);
      case _FileKind.dart:
        final diamond = Path()
          ..moveTo(w * 0.50, h * 0.14)
          ..lineTo(w * 0.82, h * 0.50)
          ..lineTo(w * 0.50, h * 0.86)
          ..lineTo(w * 0.18, h * 0.50)
          ..close();
        canvas.drawPath(diamond, stroke);
      case _FileKind.other:
        final file = Path()
          ..moveTo(w * 0.30, h * 0.14)
          ..lineTo(w * 0.62, h * 0.14)
          ..lineTo(w * 0.78, h * 0.32)
          ..lineTo(w * 0.78, h * 0.86)
          ..lineTo(w * 0.22, h * 0.86)
          ..lineTo(w * 0.22, h * 0.14)
          ..close();
        canvas.drawPath(file, stroke);
        canvas.drawLine(Offset(w * 0.62, h * 0.14), Offset(w * 0.62, h * 0.34), stroke);
        canvas.drawLine(Offset(w * 0.62, h * 0.34), Offset(w * 0.78, h * 0.34), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _FileTypeSpritePainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.tint != tint;
  }
}

class _TurnFooter extends StatelessWidget {
  const _TurnFooter({
    required this.message,
    this.onCopy,
    this.onShare,
    this.onFork,
  });

  final ChatMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final VoidCallback? onFork;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _footerIcon(context, key: const Key('chat-action-copy'), glyph: OcGlyphKind.copy, tooltip: t(context, 'chat.messageBody.actions.copyAnswer'), onPressed: onCopy),
              _footerIcon(context, key: const Key('chat-action-share'), glyph: OcGlyphKind.share, tooltip: t(context, 'chat.messageBody.actions.shareAnswer'), onPressed: onShare),
              _footerIcon(
                context,
                key: Key('chat-action-fork-${message.id}'),
                glyph: OcGlyphKind.branch,
                tooltip: t(context, 'chat.messageBody.actions.fork'),
                onPressed: onFork,
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.tokensPerSecond != null)
                _metric(
                  context,
                  key: Key('chat-tps-${message.id}'),
                  glyph: OcGlyphKind.bolt,
                  label: message.tokensPerSecond!,
                ),
              if (message.processedLabel != null)
                _metric(
                  context,
                  key: Key('chat-footer-duration-${message.id}'),
                  glyph: OcGlyphKind.hourglass,
                  label: message.processedLabel!,
                ),
              if (message.completedClock != null)
                _metric(
                  context,
                  key: Key('chat-footer-clock-${message.id}'),
                  glyph: OcGlyphKind.clock,
                  label: message.completedClock!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, {Key? key, required OcGlyphKind glyph, required String label}) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          OcGlyph(glyph, size: OcOptical.footerGlyph, strokeWidth: OcOptical.footerGlyphStrokeVisual, color: OcTokens.of(context).mutedForeground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: OcOptical.footerMeta,
              height: OcOptical.footerMetaHeight,
              color: OcTokens.of(context).mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerIcon(
    BuildContext context, {
    required Key key,
    required OcGlyphKind glyph,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        customBorder: const CircleBorder(),
        onTap: onPressed ?? () {},
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: OcGlyph(glyph, size: OcOptical.footerGlyph, strokeWidth: OcOptical.footerGlyphStrokeVisual, color: OcTokens.of(context).mutedForeground),
        ),
      ),
    );
  }
}

bool _isImagePreviewPart(ChatPart part) =>
    part.kind == ChatPartKind.fileOp &&
    (part.toolName == 'image-preview' || (part.metadata['mime']?.toString().startsWith('image/') ?? false));

bool _isActivityPart(ChatPart part) {
  if (_isImagePreviewPart(part)) return false;
  if (part.kind == ChatPartKind.diff || part.kind == ChatPartKind.permission) return false;
  return part.kind == ChatPartKind.fileOp ||
      part.kind == ChatPartKind.task ||
      part.kind == ChatPartKind.tool;
}

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
    var painted = 0;
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
            padding: EdgeInsets.only(top: painted == 0 ? 0 : OcOptical.activityRowGap),
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
        painted += 1;
        index = grouped.end;
        continue;
      }
      if (isSkillGroupTool(part.toolName)) {
        final grouped = collectConsecutiveSkillTools(parts, index);
        children.add(
          Padding(
            padding: EdgeInsets.only(top: painted == 0 ? 0 : OcOptical.activityRowGap),
            child: _SkillToolGroup(parts: grouped.items),
          ),
        );
        painted += 1;
        index = grouped.end;
        continue;
      }
      children.add(
        Padding(
          padding: EdgeInsets.only(top: painted == 0 ? 0 : OcOptical.activityRowGap),
          child: ToolPartCard(part: part, onPermission: onPermission),
        ),
      );
      painted += 1;
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
    this.processedLabel,
    this.agentCount = 0,
  });

  final String messageId;
  final bool active;
  final bool initiallyExpanded;
  final Widget child;
  final String? processedLabel;
  final int agentCount;

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
                OcGlyph(
                  OcGlyphKind.layers,
                  size: OcOptical.footerGlyph,
                  strokeWidth: OcOptical.listGlyphStroke,
                  color: OcTokens.of(context).mutedForeground,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          status,
                          key: Key('chat-activity-status-${widget.messageId}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: OcOptical.meta,
                            fontWeight: FontWeight.w500,
                            height: OcOptical.metaHeight,
                            color: OcTokens.of(context).foreground,
                          ),
                        ),
                      ),
                      if (!widget.active && widget.processedLabel != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          widget.processedLabel!,
                          key: Key('chat-activity-duration-${widget.messageId}'),
                          style: TextStyle(
                            fontSize: OcOptical.meta,
                            height: OcOptical.metaHeight,
                            color: OcTokens.of(context).mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.agentCount > 0) _AgentCountChip(count: widget.agentCount),
                if (!lockedOpen)
                  OcGlyph(
                    open ? OcGlyphKind.chevronDown : OcGlyphKind.chevronRight,
                    size: OcOptical.chevron,
                    strokeWidth: OcOptical.listGlyphStroke,
                    color: OcTokens.of(context).mutedForeground,
                  ),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(
              top: OcOptical.activityExpandedGap,
              left: OcOptical.activityExpandedIndent - OcOptical.activityChildIndent,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: context.oc.border.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: OcOptical.activityChildIndent),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: OcTokens.textMarkdown,
                    height: OcOptical.chatBodyHeight,
                    color: context.oc.foreground,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
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
        _ActivityToolRow(
          rowKey: Key('chat-context-group-${widget.parts.first.id}'),
          leading: OcGlyphKind.search,
          title: title,
          detail: summary.isEmpty ? null : summary,
          detailKey: Key('chat-context-summary-${widget.parts.first.id}'),
          expanded: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: OcOptical.activityChildIndent, top: OcOptical.activityRowGap),
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

class _SkillToolGroup extends StatefulWidget {
  const _SkillToolGroup({required this.parts});

  final List<ChatPart> parts;

  @override
  State<_SkillToolGroup> createState() => _SkillToolGroupState();
}

class _SkillToolGroupState extends State<_SkillToolGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = summarizeSkillNames(widget.parts.map(getSkillNameFromPart));
    final label = summary.hiddenCount > 0
        ? t(context, 'chat.skillGroup.summaryOverflow', {
            'names': summary.joinedVisible,
            'count': '${summary.hiddenCount}',
          })
        : summary.joinedVisible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActivityToolRow(
          rowKey: Key('chat-skill-group-${widget.parts.first.id}'),
          leading: OcGlyphKind.folder,
          title: t(context, 'chat.tools.display.skill'),
          detail: label.isEmpty ? null : label,
          detailKey: Key('chat-skill-summary-${widget.parts.first.id}'),
          expanded: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: OcOptical.activityChildIndent, top: OcOptical.activityRowGap),
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

class _ExpandableToolCard extends StatefulWidget {
  const _ExpandableToolCard({
    required this.part,
    required this.cardKey,
    required this.displayTitle,
    required this.leading,
  });

  final ChatPart part;
  final String cardKey;
  final String displayTitle;
  final OcGlyphKind leading;

  @override
  State<_ExpandableToolCard> createState() => _ExpandableToolCardState();
}

class _ExpandableToolCardState extends State<_ExpandableToolCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final output = widget.part.body;
    final command = _toolRowCommand(widget.part);
    return Column(
      key: Key(widget.cardKey),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActivityToolRow(
          rowKey: Key('${widget.cardKey}-toggle'),
          leading: widget.leading,
          title: widget.displayTitle,
          duration: _toolRowDuration(widget.part),
          detail: command,
          expanded: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded && output != null && output.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              left: OcOptical.activityChildIndent,
              top: OcOptical.activityRowGap,
            ),
            child: _ActivityInkText(
              output,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.35,
                color: context.oc.foreground,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActivityToolRow extends StatelessWidget {
  const _ActivityToolRow({
    required this.leading,
    required this.title,
    required this.expanded,
    required this.onTap,
    this.rowKey,
    this.duration,
    this.detail,
    this.detailKey,
  });

  final Key? rowKey;
  final OcGlyphKind leading;
  final String title;
  final String? duration;
  final String? detail;
  final Key? detailKey;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    return Pressable(
      key: rowKey,
      haptic: HapticStrength.light,
      highlight: false,
      onPressed: onTap,
      child: Row(
        children: [
          OcGlyph(
            leading,
            size: OcOptical.toolRowGlyph,
            strokeWidth: OcOptical.headerGlyphStrokeVisual,
            color: tokens.foreground,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: OcOptical.meta,
              fontWeight: FontWeight.w500,
              height: OcOptical.metaHeight,
              color: tokens.foreground,
            ),
          ),
          if (duration != null && duration!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              duration!,
              style: TextStyle(
                fontSize: OcOptical.meta,
                height: OcOptical.metaHeight,
                color: tokens.mutedForeground,
              ),
            ),
          ],
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Expanded(
              child: _ActivityInkText(
                detail!,
                key: detailKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: OcOptical.meta,
                  height: OcOptical.metaHeight,
                  color: tokens.foreground,
                ),
              ),
            ),
          ] else
            const Spacer(),
          OcGlyph(
            expanded ? OcGlyphKind.chevronDown : OcGlyphKind.chevronRight,
            size: OcOptical.chevron,
            strokeWidth: OcOptical.listGlyphStroke,
            color: tokens.mutedForeground,
          ),
        ],
      ),
    );
  }
}

/// Foreground narrative with a green `pub` badge when that token appears.
class _ActivityInkText extends StatelessWidget {
  const _ActivityInkText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final base = style ?? TextStyle(color: context.oc.foreground);
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\bpub\b');
    var start = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: base));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: context.oc.statusSuccess,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'pub',
            style: base.copyWith(
              color: context.oc.background,
              fontSize: (base.fontSize ?? OcOptical.meta) - 1,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ));
      start = match.end;
    }
    if (spans.isEmpty) {
      return Text(text, maxLines: maxLines, overflow: overflow, style: base);
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: base));
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

String? _toolRowCommand(ChatPart part) {
  final fromMeta = part.metadata['command']?.toString().trim()
      ?? part.metadata['cmd']?.toString().trim();
  if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
  final title = part.title.trim();
  if (title.isNotEmpty && title.toLowerCase() != (part.toolName ?? '').toLowerCase()) {
    return title;
  }
  return null;
}

String? _toolRowDuration(ChatPart part) {
  final labeled = part.metadata['duration']?.toString().trim()
      ?? part.metadata['durationLabel']?.toString().trim();
  if (labeled != null && labeled.isNotEmpty) return labeled;
  final raw = part.metadata['durationMs'];
  final ms = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
  if (ms == null || ms <= 0) return null;
  if (ms >= 1000) return '${(ms / 1000).toStringAsFixed(1)}s';
  return '${ms.round()}ms';
}

class _GeneratedResultCard extends StatelessWidget {
  const _GeneratedResultCard({required this.result, required this.partId});

  final GeneratedResult result;
  final String partId;

  @override
  Widget build(BuildContext context) {
    final isCommit = result.kind == 'commit';
    return _CardShell(
      key: Key('chat-generated-${result.kind}-$partId'),
      title: t(
        context,
        isCommit ? 'chat.generatedResult.commit.title' : 'chat.generatedResult.pullRequest.title',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCommit) ...[
            Text(result.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (result.highlights.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(t(context, 'chat.generatedResult.commit.highlights'), style: TextStyle(color: OcTokens.of(context).mutedForeground, fontSize: 12)),
              for (final item in result.highlights) Text('• $item'),
            ],
          ] else ...[
            if (result.title.isNotEmpty) ...[
              Text(t(context, 'chat.generatedResult.pullRequest.titleLabel'), style: TextStyle(color: OcTokens.of(context).mutedForeground, fontSize: 12)),
              Text(result.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            if (result.body != null) ...[
              const SizedBox(height: 6),
              Text(t(context, 'chat.generatedResult.pullRequest.bodyLabel'), style: TextStyle(color: OcTokens.of(context).mutedForeground, fontSize: 12)),
              Text(result.body!),
            ],
          ],
        ],
      ),
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
        if (part.toolName == 'image-preview' || (part.metadata['mime']?.toString().startsWith('image/') ?? false)) {
          return _CardShell(
            key: Key('chat-tool-image-${part.id}'),
            title: t(context, 'chat.tools.display.image'),
            subtitle: part.path ?? part.title,
            child: part.body == null ? null : Text(part.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
          );
        }
        final path = part.path ?? '';
        final card = _CardShell(
          key: Key('chat-tool-file-${part.id}'),
          title: part.title,
          subtitle: part.path ?? part.status,
          child: part.body == null ? null : Text(part.body!, maxLines: 4, overflow: TextOverflow.ellipsis),
        );
        if (!isHtmlFile(path)) return card;
        return Pressable(
          key: Key('chat-tool-html-${part.id}'),
          haptic: HapticStrength.light,
          onPressed: () => FilePreviewScope.maybeOf(context)?.onOpenPath(path),
          child: card,
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
        if (isBashTool(part.toolName)) {
          return _ExpandableToolCard(
            part: part,
            cardKey: 'chat-tool-bash-${part.id}',
            displayTitle: t(context, 'chat.tools.display.bash'),
            leading: OcGlyphKind.terminal,
          );
        }
        if (isWebFetchTool(part.toolName)) {
          return _ExpandableToolCard(
            part: part,
            cardKey: 'chat-tool-fetch-${part.id}',
            displayTitle: t(context, 'chat.tools.display.webfetch'),
            leading: OcGlyphKind.link,
          );
        }
        if (isWebSearchTool(part.toolName)) {
          return _ExpandableToolCard(
            part: part,
            cardKey: 'chat-tool-search-${part.id}',
            displayTitle: t(
              context,
              normalizeContextToolName(part.toolName) == 'codesearch'
                  ? 'chat.tools.display.codesearch'
                  : 'chat.tools.display.websearch',
            ),
            leading: OcGlyphKind.search,
          );
        }
        if (isQuestionTool(part.toolName)) {
          return _CardShell(
            key: Key('chat-tool-question-${part.id}'),
            title: t(context, 'chat.tools.display.question'),
            subtitle: part.title,
            child: part.body == null ? null : Text(part.body!),
          );
        }
        return _CardShell(
          key: Key('chat-tool-row-${part.id}'),
          title: part.title,
          subtitle: part.status ?? part.toolName,
          child: part.body == null ? null : Text(part.body!, maxLines: 6, overflow: TextOverflow.ellipsis),
        );
      case ChatPartKind.mermaid:
        return _MermaidCard(part: part);
      case ChatPartKind.text:
      case ChatPartKind.reasoning:
      case ChatPartKind.compaction:
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
              style: TextStyle(color: OcTokens.of(context).mutedForeground, fontSize: 12),
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
                    color: row.$1 == null ? OcTokens.of(context).mutedForeground : Theme.of(context).colorScheme.error,
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
                    color: row.$2 == null ? OcTokens.of(context).mutedForeground : Theme.of(context).colorScheme.primary,
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
  return OcTokens.of(context).mutedForeground;
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: OcTokens.of(context).mutedForeground),
                  ),
                ),
                Text(
                  _permissionToolLabel(tool),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: OcTokens.of(context).mutedForeground),
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
                  Text(t(context, 'chat.permissionCard.patterns'), style: TextStyle(color: OcTokens.of(context).mutedForeground, fontSize: 11)),
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
        Text('${t(context, 'chat.permissionCard.workingDirectory')} $cwd', style: TextStyle(color: OcTokens.of(context).mutedForeground, fontSize: 12)),
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
      Text(t(context, 'chat.permissionCard.request'), style: TextStyle(color: OcTokens.of(context).mutedForeground, fontSize: 11)),
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
    Text(t(context, 'chat.permissionCard.details'), style: TextStyle(color: OcTokens.of(context).mutedForeground, fontSize: 11)),
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
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.oc.foreground,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, style: TextStyle(color: OcTokens.of(context).mutedForeground, fontSize: 12)),
              ),
            if (child != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: context.oc.foreground),
                  child: child!,
                ),
              ),
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
