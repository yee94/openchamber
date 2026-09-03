import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

/// Native composer chrome. iOS is Cupertino; Android is Material 3.
/// Always the product path — no WebView composer, no iosNativeUi gate.
/// Deeper UIKit liquid-glass overlay / Android ImeSync analogue: later slice.
class ComposerBar extends StatelessWidget {
  const ComposerBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
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
      ),
    );

    final attach = IconButton(
      key: const Key('composer-attach'),
      tooltip: t(context, 'chat.composer.attach'),
      onPressed: onAttach,
      icon: Icon(ios ? CupertinoIcons.add : Icons.add),
    );
    final send = IconButton(
      key: const Key('composer-send'),
      tooltip: t(context, 'chat.composer.send'),
      onPressed: onSend,
      icon: Icon(ios ? CupertinoIcons.arrow_up_circle_fill : Icons.send),
    );

    return Material(
      elevation: ios ? 0 : 2,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            children: [
              attach,
              Expanded(child: field),
              send,
            ],
          ),
        ),
      ),
    );
  }
}
