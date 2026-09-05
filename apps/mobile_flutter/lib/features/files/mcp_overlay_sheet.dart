import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/openchamber_api.dart';
import '../../data/openchamber_http.dart';
import '../../data/settings_remote.dart';
import '../../l10n/app_strings.dart';
import '../../motion/pressable.dart';
import '../../native/haptics.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

Future<void> showMcpOverlaySheet({
  required BuildContext context,
  required AppController controller,
  String? directory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.72,
      child: McpOverlaySheet(controller: controller, directory: directory),
    ),
  );
}

class McpOverlaySheet extends StatefulWidget {
  const McpOverlaySheet({super.key, required this.controller, this.directory});

  final AppController controller;
  final String? directory;

  @override
  State<McpOverlaySheet> createState() => _McpOverlaySheetState();
}

class _McpOverlaySheetState extends State<McpOverlaySheet> {
  List<SettingsNamedItem> _servers = const [];
  Map<String, McpRuntimeStatus> _status = const {};
  String? _errorKey;
  String? _busyName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _errorKey = null;
    });
    try {
      await widget.controller.remoteSettings.loadMcp();
      final status = await widget.controller.loadMcpRuntimeStatus();
      if (!mounted) return;
      setState(() {
        _servers = widget.controller.remoteSettings.mcp.value ?? const [];
        _status = status;
        _loading = false;
      });
    } on OpenChamberHttpException {
      if (!mounted) return;
      setState(() {
        _servers = widget.controller.remoteSettings.mcp.value ?? const [];
        _errorKey = widget.controller.remoteSettings.mcp.errorKey ?? 'mcpDropdown.error.statusFailed';
        _loading = false;
      });
    }
  }

  Future<void> _toggle(SettingsNamedItem server, bool connected) async {
    setState(() => _busyName = server.id);
    final ok = await widget.controller.setMcpRuntimeConnected(
      name: server.id,
      connected: connected,
      directory: widget.directory,
    );
    if (!mounted) return;
    setState(() => _busyName = null);
    if (!ok) {
      final error = widget.controller.lastMutationErrorKey;
      if (error != null) setState(() => _errorKey = error);
      return;
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.oc;
    final names = {
      ..._servers.map((item) => item.id),
      ..._status.keys,
    }.toList()
      ..sort();
    return Material(
      key: const Key('mcp-overlay-sheet'),
      color: tokens.pageBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + MediaQuery.viewPaddingOf(context).bottom),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t(context, 'mcpDropdown.title'),
                    style: ocCssInk(TextStyle(
                      fontSize: OcTokens.textUiLabel,
                      fontWeight: FontWeight.w600,
                      color: tokens.foreground,
                    )),
                  ),
                ),
                Pressable(
                  key: const Key('mcp-overlay-add'),
                  haptic: HapticStrength.light,
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    widget.controller.requestSettingsSlug('mcp');
                  },
                  child: const SizedBox(width: 36, height: 36, child: Center(child: OcGlyph(OcGlyphKind.plus, size: 16))),
                ),
                Pressable(
                  key: const Key('mcp-overlay-refresh'),
                  haptic: HapticStrength.light,
                  onPressed: () => unawaited(_reload()),
                  child: Semantics(
                    button: true,
                    label: t(context, 'mcpDropdown.actions.refreshAria'),
                    child: const SizedBox(width: 36, height: 36, child: Center(child: OcGlyph(OcGlyphKind.undo, size: 16))),
                  ),
                ),
                Pressable(
                  key: const Key('mcp-overlay-close'),
                  haptic: HapticStrength.light,
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Semantics(
                    button: true,
                    label: t(context, 'mobile.surface.closeAria'),
                    child: const SizedBox(width: 36, height: 36, child: Center(child: OcGlyph(OcGlyphKind.xmark, size: 16))),
                  ),
                ),
              ],
            ),
            if (_errorKey != null) Text(t(context, _errorKey!), style: TextStyle(color: tokens.statusError)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : names.isEmpty
                      ? Center(child: Text(t(context, 'mcpDropdown.empty.configureInConfig')))
                      : ListView(
                          key: const Key('mcp-overlay-list'),
                          children: [
                            for (final name in names)
                              _McpRow(
                                name: name,
                                connected: _status[name]?.connected == true,
                                busy: _busyName == name,
                                onChanged: (value) => unawaited(_toggle(SettingsNamedItem(id: name, title: name), value)),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _McpRow extends StatelessWidget {
  const _McpRow({
    required this.name,
    required this.connected,
    required this.busy,
    required this.onChanged,
  });

  final String name;
  final bool connected;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          OcGlyph(OcGlyphKind.mcp, size: 16, color: context.oc.foreground),
          const SizedBox(width: 10),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Switch(
            key: Key('mcp-overlay-toggle-$name'),
            value: connected,
            onChanged: busy ? null : onChanged,
          ),
        ],
      ),
    );
  }
}
