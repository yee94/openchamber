import 'package:flutter/widgets.dart';

class FilePreviewScope extends InheritedWidget {
  const FilePreviewScope({
    super.key,
    required this.onOpenPath,
    required super.child,
  });

  final void Function(String path) onOpenPath;

  static FilePreviewScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FilePreviewScope>();
  }

  @override
  bool updateShouldNotify(FilePreviewScope oldWidget) => onOpenPath != oldWidget.onOpenPath;
}
