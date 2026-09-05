import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

/// One row from official `buildSessionMenuItems` that this client can show.
class SessionOverflowItem {
  const SessionOverflowItem({
    required this.id,
    required this.labelKey,
    required this.glyph,
    required this.onTap,
    this.destructive = false,
    this.separated = false,
  });

  final String id;
  final String labelKey;
  final OcGlyphKind glyph;
  final VoidCallback onTap;
  final bool destructive;
  final bool separated;
}

/// Official session overflow order: rename / pin / share|copy+unshare / refresh / archive / delete.
List<SessionOverflowItem> buildSessionOverflowItems({
  required bool pinned,
  required bool shared,
  required VoidCallback onRename,
  required VoidCallback onTogglePin,
  VoidCallback? onShare,
  VoidCallback? onCopyLink,
  VoidCallback? onUnshare,
  required VoidCallback onRefreshTranscript,
  required VoidCallback onArchive,
  required VoidCallback onDelete,
}) {
  return [
    SessionOverflowItem(
      id: 'rename',
      labelKey: 'sessions.sidebar.session.menu.rename',
      glyph: OcGlyphKind.edit,
      onTap: onRename,
    ),
    SessionOverflowItem(
      id: 'pin',
      labelKey: pinned
          ? 'sessions.sidebar.session.menu.unpin'
          : 'sessions.sidebar.session.menu.pin',
      glyph: OcGlyphKind.bolt,
      onTap: onTogglePin,
    ),
    if (shared) ...[
      if (onCopyLink != null)
        SessionOverflowItem(
          id: 'copyLink',
          labelKey: 'sessions.sidebar.session.menu.copyLink',
          glyph: OcGlyphKind.copy,
          onTap: onCopyLink,
        ),
      if (onUnshare != null)
        SessionOverflowItem(
          id: 'unshare',
          labelKey: 'sessions.sidebar.session.menu.unshare',
          glyph: OcGlyphKind.link,
          onTap: onUnshare,
        ),
    ] else if (onShare != null)
      SessionOverflowItem(
        id: 'share',
        labelKey: 'sessions.sidebar.session.menu.share',
        glyph: OcGlyphKind.share,
        onTap: onShare,
      ),
    SessionOverflowItem(
      id: 'refreshTranscript',
      labelKey: 'sessions.sidebar.session.menu.refreshTranscript',
      glyph: OcGlyphKind.undo,
      onTap: onRefreshTranscript,
    ),
    SessionOverflowItem(
      id: 'archive',
      labelKey: 'sessions.sidebar.bulkActions.archive',
      glyph: OcGlyphKind.layers,
      onTap: onArchive,
    ),
    SessionOverflowItem(
      id: 'delete',
      labelKey: 'sessions.sidebar.bulkActions.delete',
      glyph: OcGlyphKind.xmark,
      onTap: onDelete,
      destructive: true,
      separated: true,
    ),
  ];
}

List<SessionOverflowItem> buildProjectOverflowItems({
  required bool gitRepository,
  required VoidCallback onNewSession,
  VoidCallback? onNewWorktree,
  required VoidCallback onSyncSessions,
  required VoidCallback onEditProject,
  required VoidCallback onCloseProject,
}) {
  return [
    SessionOverflowItem(
      id: 'newSession',
      labelKey: 'sessions.sidebar.project.actions.newSession',
      glyph: OcGlyphKind.plus,
      onTap: onNewSession,
    ),
    if (gitRepository && onNewWorktree != null)
      SessionOverflowItem(
        id: 'newWorktree',
        labelKey: 'sessions.sidebar.project.actions.newWorktree',
        glyph: OcGlyphKind.branch,
        onTap: onNewWorktree,
      ),
    SessionOverflowItem(
      id: 'syncSessions',
      labelKey: 'sessions.sidebar.project.actions.syncSessions',
      glyph: OcGlyphKind.undo,
      onTap: onSyncSessions,
    ),
    SessionOverflowItem(
      id: 'edit',
      labelKey: 'sessions.sidebar.project.actions.edit',
      glyph: OcGlyphKind.edit,
      onTap: onEditProject,
    ),
    SessionOverflowItem(
      id: 'closeProject',
      labelKey: 'sessions.sidebar.project.actions.closeProject',
      glyph: OcGlyphKind.xmark,
      onTap: onCloseProject,
      destructive: true,
      separated: true,
    ),
  ];
}

List<SessionOverflowItem> buildWorktreeOverflowItems({
  required VoidCallback onNewSession,
  required VoidCallback onDeleteWorktree,
}) {
  return [
    SessionOverflowItem(
      id: 'newSession',
      labelKey: 'sessions.sidebar.project.actions.newSession',
      glyph: OcGlyphKind.plus,
      onTap: onNewSession,
    ),
    SessionOverflowItem(
      id: 'deleteWorktree',
      labelKey: 'mobile.projectEdit.deleteWorktreeConfirmButton',
      glyph: OcGlyphKind.xmark,
      onTap: onDeleteWorktree,
      destructive: true,
      separated: true,
    ),
  ];
}

Future<void> showSessionOverflowSheet({
  required BuildContext context,
  required String title,
  required List<SessionOverflowItem> items,
  Key sheetKey = const Key('session-overflow-sheet'),
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => SessionOverflowSheet(sheetKey: sheetKey, title: title, items: items),
  );
}

class SessionOverflowSheet extends StatelessWidget {
  const SessionOverflowSheet({
    super.key,
    required this.title,
    required this.items,
    this.sheetKey = const Key('session-overflow-sheet'),
  });

  final String title;
  final List<SessionOverflowItem> items;
  final Key sheetKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final groups = <List<SessionOverflowItem>>[];
    for (final item in items) {
      final current = groups.isEmpty ? null : groups.last;
      if (current == null || current.first.separated != item.separated) {
        groups.add([item]);
      } else {
        current.add(item);
      }
    }

    return Material(
      key: sheetKey,
      color: tokens.pageBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + MediaQuery.viewPaddingOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ocCssInk(TextStyle(
                      fontSize: OcTokens.textUiLabel,
                      fontWeight: FontWeight.w600,
                      color: tokens.foreground,
                    )),
                  ),
                ),
                Pressable(
                  key: const Key('session-overflow-close'),
                  haptic: HapticStrength.light,
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Semantics(
                    button: true,
                    label: t(context, 'mobile.surface.closeAria'),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: OcGlyph(
                          OcGlyphKind.xmark,
                          size: 16,
                          strokeWidth: OcOptical.detailNavGlyphStroke,
                          color: tokens.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < groups.length; i += 1) ...[
              if (i > 0) const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    for (final item in groups[i])
                      _SessionOverflowRow(item: item),
                  ],
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

class _SessionOverflowRow extends StatelessWidget {
  const _SessionOverflowRow({required this.item});

  final SessionOverflowItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final color = item.destructive ? tokens.statusError : tokens.foreground;
    return Pressable(
      key: Key('session-overflow-${item.id}'),
      haptic: HapticStrength.light,
      onPressed: () {
        Navigator.of(context).maybePop();
        item.onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              OcGlyph(
                item.glyph,
                size: OcOptical.detailNavGlyph,
                strokeWidth: OcOptical.detailNavGlyphStroke,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t(context, item.labelKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ocCssInk(TextStyle(
                    fontSize: OcTokens.textUiLabel,
                    fontWeight: FontWeight.w400,
                    color: color,
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
