import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';

Future<String?> showTextPromptDialog({
  required BuildContext context,
  required String titleKey,
  required String fieldLabelKey,
  required String confirmKey,
  required String cancelKey,
  String initial = '',
  Key fieldKey = const Key('text-prompt-field'),
  Key confirmWidgetKey = const Key('text-prompt-confirm'),
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(t(dialogContext, titleKey)),
        content: TextField(
          key: fieldKey,
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: t(dialogContext, fieldLabelKey)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t(dialogContext, cancelKey)),
          ),
          TextButton(
            key: confirmWidgetKey,
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(t(dialogContext, confirmKey)),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String titleKey,
  required String messageKey,
  required String confirmKey,
  required String cancelKey,
  Map<String, String>? messageParams,
  Key confirmWidgetKey = const Key('confirm-dialog-confirm'),
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(t(dialogContext, titleKey)),
        content: Text(t(dialogContext, messageKey, messageParams)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t(dialogContext, cancelKey)),
          ),
          TextButton(
            key: confirmWidgetKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: Theme.of(dialogContext).colorScheme.error)
                : null,
            child: Text(t(dialogContext, confirmKey)),
          ),
        ],
      );
    },
  );
  return result == true;
}

Future<bool> copyTextToClipboard(String value) async {
  try {
    await Clipboard.setData(ClipboardData(text: value));
    return true;
  } catch (_) {
    return false;
  }
}
