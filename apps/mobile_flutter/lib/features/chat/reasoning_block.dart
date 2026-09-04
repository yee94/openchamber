import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/chat_rebuild_counters.dart';
import '../../data/chat_timeline.dart';
import '../../l10n/app_strings.dart';
import '../../motion/oc_motion.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';
import 'chat_markdown_body.dart';

/// Official `ReasoningTimelineBlock` (`packages/ui/.../ReasoningPart.tsx`).
///
/// Motion: height 200ms `easeOut`; inner fade/translate 180ms `easeOut`;
/// Markdown unmounts 200ms after collapse so a long collapsed trace is not
/// laid out while the transcript scrolls.
class ReasoningTraceBlock extends StatefulWidget {
  const ReasoningTraceBlock({
    super.key,
    required this.part,
    this.isLive = false,
  });

  final ChatPart part;
  final bool isLive;

  static const int summaryMaxChars = 80;

  @override
  State<ReasoningTraceBlock> createState() => _ReasoningTraceBlockState();
}

class _ReasoningTraceBlockState extends State<ReasoningTraceBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _height;
  late final Animation<double> _factor;
  bool _userExpanded = false;
  bool _userTouched = false;
  bool _mountBody = false;
  Timer? _unmount;

  bool get _canAutoExpand => widget.isLive && widget.part.status != 'completed';

  bool get _expanded => _userTouched ? _userExpanded : _canAutoExpand;

  @override
  void initState() {
    super.initState();
    _height = AnimationController(vsync: this, duration: OcMotion.reasoningExpand);
    _factor = CurvedAnimation(parent: _height, curve: OcMotion.reasoningExpandEase);
    if (_expanded) {
      _mountBody = true;
      _height.value = 1;
    }
  }

  @override
  void didUpdateWidget(ReasoningTraceBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_userTouched && oldWidget.isLive != widget.isLive) {
      _syncHeight();
    }
  }

  @override
  void dispose() {
    _unmount?.cancel();
    _height.dispose();
    super.dispose();
  }

  void _toggle() {
    final next = !_expanded;
    setState(() {
      _userTouched = true;
      _userExpanded = next;
    });
    _syncHeight();
  }

  void _syncHeight() {
    _unmount?.cancel();
    if (_expanded) {
      setState(() => _mountBody = true);
      _height.forward();
      return;
    }
    _height.reverse();
    // Official unmounts after EXPANDED_CONTENT_UNMOUNT_DELAY_MS (200),
    // overlapping the 200ms easeOut height animation.
    _unmount = Timer(OcMotion.reasoningUnmountDelay, () {
      if (!mounted || _expanded) return;
      setState(() => _mountBody = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ChatRebuildCounters.recordReasoning(widget.part.id);
    final text = widget.part.body ?? '';
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final tokens = OcTokens.of(context);
    final justification = widget.part.title == 'justification';
    final labelKey = widget.isLive
        ? (justification ? 'chat.reasoningTrace.justification' : 'chat.reasoningTrace.thinking')
        : _expanded
            ? (justification ? 'chat.reasoningTrace.justification' : 'chat.reasoningTrace.thinking')
            : (justification ? 'chat.reasoningTrace.justification' : 'chat.reasoningTrace.thought');
    final summary = reasoningSummary(text);
    return Column(
      key: Key('chat-reasoning-${widget.part.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: Key('chat-reasoning-toggle-${widget.part.id}'),
          onTap: _toggle,
          child: Semantics(
            button: true,
            expanded: _expanded,
            label: t(
              context,
              _expanded ? 'chat.reasoningTrace.collapseAria' : 'chat.reasoningTrace.expandAria',
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  OcGlyph(
                    _expanded ? OcGlyphKind.chevronDown : OcGlyphKind.sparkles,
                    size: OcOptical.footerGlyph,
                    strokeWidth: OcOptical.listGlyphStroke,
                    color: tokens.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t(context, labelKey),
                    key: Key('chat-reasoning-label-${widget.part.id}'),
                    style: TextStyle(
                      fontSize: OcOptical.meta,
                      fontWeight: FontWeight.w500,
                      height: OcOptical.metaHeight,
                      color: tokens.foreground.withValues(alpha: 0.85),
                    ),
                  ),
                  if (!_expanded && !widget.isLive && summary.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summary,
                        key: Key('chat-reasoning-summary-${widget.part.id}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: OcOptical.meta,
                          height: OcOptical.metaHeight,
                          color: tokens.mutedForeground.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              ),
            ),
          ),
        ),
        if (_mountBody)
          SizeTransition(
            sizeFactor: _factor,
            axisAlignment: -1,
            child: AnimatedOpacity(
              duration: OcMotion.reasoningContentFade,
              curve: OcMotion.reasoningExpandEase,
              opacity: _expanded ? 1 : 0,
              child: AnimatedSlide(
                duration: OcMotion.reasoningContentFade,
                curve: OcMotion.reasoningExpandEase,
                offset: _expanded
                    ? Offset.zero
                    : const Offset(0, -OcMotion.reasoningContentSlidePx / OcMotion.reasoningExpandedMaxHeight),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2, bottom: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: tokens.border.withValues(alpha: 0.4), width: 1),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: widget.isLive
                          ? ChatMarkdownBody(
                              cacheKey: 'reasoning-${widget.part.id}',
                              text: text,
                              isLive: true,
                            )
                          : ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: OcMotion.reasoningExpandedMaxHeight,
                              ),
                              child: SingleChildScrollView(
                                primary: false,
                                child: ChatMarkdownBody(
                                  cacheKey: 'reasoning-${widget.part.id}',
                                  text: text,
                                  isLive: false,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String cleanReasoningText(String text) {
  return text
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'^>\s?'), '').trimRight())
      .where((line) => line.trim().isNotEmpty)
      .join('\n')
      .trim();
}

String stripReasoningMarkdown(String text) {
  return text
      .replaceAll(RegExp(r'<!--\s*-->'), '')
      .replaceAllMapped(RegExp(r'```[\w]*\n?([\s\S]*?)```'), (match) => (match.group(1) ?? '').trim())
      .replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match.group(1) ?? '')
      .replaceAllMapped(RegExp(r'\*{1,3}([^*]+)\*{1,3}'), (match) => match.group(1) ?? '')
      .replaceAllMapped(RegExp(r'_{1,3}([^_]+)_{1,3}'), (match) => match.group(1) ?? '')
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (match) => match.group(1) ?? '')
      .replaceAll(RegExp(r'^>\s?', multiLine: true), '')
      .replaceAll(RegExp(r'^[-*_]{3,}\s*$', multiLine: true), '')
      .trim();
}

String reasoningSummary(String text) {
  final flat = stripReasoningMarkdown(cleanReasoningText(text)).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.length <= ReasoningTraceBlock.summaryMaxChars) return flat;
  final cut = flat.lastIndexOf(' ', ReasoningTraceBlock.summaryMaxChars);
  final end = cut > 0 ? cut : ReasoningTraceBlock.summaryMaxChars;
  return '${flat.substring(0, end).trimRight()}…';
}
