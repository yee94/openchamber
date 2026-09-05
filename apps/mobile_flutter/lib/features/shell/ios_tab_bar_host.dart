import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../native/platform_channels.dart';

const iosTabBarDockHeight = 49.0;

class IosTabBarHost extends StatefulWidget {
  const IosTabBarHost({
    super.key,
    required this.selectedId,
    required this.onSelect,
  });

  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<IosTabBarHost> createState() => _IosTabBarHostState();
}

class _IosTabBarHostState extends State<IosTabBarHost> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(IosTabBarHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _push();
  }

  void _onCreated(int id) {
    _channel = MethodChannel('openchamber/tab_bar_$id');
    _channel!.setMethodCallHandler((call) async {
      if (call.method == 'select' && call.arguments is String) {
        widget.onSelect(call.arguments as String);
      }
      return null;
    });
    _push();
  }

  void _push() {
    final channel = _channel;
    if (channel == null || !context.mounted) return;
    channel.invokeMethod<void>('apply', {
      'selectedId': widget.selectedId,
      'items': [
        {'id': 'projects', 'label': t(context, 'tabs.projects'), 'symbol': 'folder'},
        {'id': 'assistant', 'label': t(context, 'tabs.assistant'), 'symbol': 'sparkles'},
        {'id': 'scheduled', 'label': t(context, 'tabs.scheduled'), 'symbol': 'calendar'},
        {'id': 'settings', 'label': t(context, 'tabs.settings'), 'symbol': 'gearshape'},
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    return UiKitView(
      viewType: OpenChamberPlatformViews.tabBar,
      creationParamsCodec: const StandardMessageCodec(),
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
      onPlatformViewCreated: _onCreated,
    );
  }
}
