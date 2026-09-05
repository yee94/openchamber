import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/local_chat_commands.dart';
import '../../data/prompt_attachment.dart';
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
    this.onPickedFiles,
    this.commands = const [],
    this.files = const [],
    this.skills = const [],
    this.snippets = const [],
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
  final ValueChanged<List<AttachmentDraft>>? onPickedFiles;
  final List<String> commands;
  final List<String> files;
  final List<String> skills;
  final List<String> snippets;

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
        case 'autocompleteSelect':
          final label = call.arguments is String ? call.arguments as String : '';
          if (label.isNotEmpty) {
            final next = applyComposerSuggestion(widget.text, label);
            widget.onText(next);
            if (shouldSubmitCommandOnSelection(label)) widget.onSend(next);
          }
        case 'pickedFiles':
          final drafts = <AttachmentDraft>[];
          final raw = call.arguments;
          if (raw is List) {
            for (final item in raw) {
              if (item is! Map) continue;
              final name = item['name']?.toString() ?? 'file';
              final mime = item['mime']?.toString() ?? item['mimeType']?.toString() ?? 'application/octet-stream';
              final encoded = item['dataBase64']?.toString() ?? '';
              if (encoded.isEmpty) continue;
              final bytes = base64Decode(encoded.contains(',') ? encoded.substring(encoded.indexOf(',') + 1) : encoded);
              if (bytes.isEmpty || bytes.length > maxPickedMediaBytes) continue;
              drafts.add(AttachmentDraft(name: name, mime: mime, bytes: Uint8List.fromList(bytes)));
            }
          }
          if (drafts.isNotEmpty) widget.onPickedFiles?.call(drafts);
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
      'autocomplete': filterComposerSuggestions(
        widget.text,
        commands: widget.commands,
        files: widget.files,
        skills: widget.skills,
        snippets: widget.snippets,
      ).map((item) => item.label).toList(),
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
