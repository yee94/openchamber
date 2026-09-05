import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../native/platform_channels.dart';
import 'composer_occupancy.dart';

class IosComposerHost extends StatefulWidget {
  const IosComposerHost({
    super.key,
    required this.visible,
    required this.warm,
    required this.text,
    required this.canSend,
    required this.canAbort,
    required this.attachments,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
    required this.onText,
    this.onOccupancy,
  });

  final bool visible;
  final bool warm;
  final String text;
  final bool canSend;
  final bool canAbort;
  final List<String> attachments;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final VoidCallback onAttach;
  final ValueChanged<String> onText;
  final ValueChanged<double>? onOccupancy;

  @override
  State<IosComposerHost> createState() => _IosComposerHostState();
}

class _IosComposerHostState extends State<IosComposerHost> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(IosComposerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _push();
  }

  void _onCreated(int id) {
    _channel = MethodChannel('openchamber/composer_$id');
    _channel!.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'send':
          widget.onSend(call.arguments is String ? call.arguments as String : '');
        case 'stop':
          widget.onStop();
        case 'attach':
          widget.onAttach();
        case 'text':
          widget.onText(call.arguments is String ? call.arguments as String : '');
        case 'occupancy':
          final height = (call.arguments as num?)?.toDouble() ?? collapsedComposerOccupancy;
          widget.onOccupancy?.call(height);
        case 'autocomplete':
          break;
      }
      return null;
    });
    if (widget.warm) {
      _channel!.invokeMethod<void>('warm');
    }
    _push();
  }

  void _push() {
    final channel = _channel;
    if (channel == null) return;
    if (!widget.visible) {
      channel.invokeMethod<void>('hide');
      return;
    }
    channel.invokeMethod<void>('apply', {
      'text': widget.text,
      'placeholder': t(context, 'chat.composer.placeholder'),
      'canSend': widget.canSend,
      'canAbort': widget.canAbort,
      'attachments': widget.attachments,
      'autocomplete': autocompleteStubFor(widget.text).map((item) => item.label).toList(),
      'visible': widget.visible,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    return UiKitView(
      viewType: OpenChamberPlatformViews.composer,
      creationParamsCodec: const StandardMessageCodec(),
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
      onPlatformViewCreated: _onCreated,
    );
  }
}
