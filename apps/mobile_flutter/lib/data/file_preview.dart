/// Official `IMAGE_EXTENSIONS` (`packages/ui/src/lib/toolHelpers.ts`).
const _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'ico', 'bmp', 'avif'};

String fileExtension(String path) {
  final name = fileNameFromPath(path).toLowerCase();
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1);
}

/// Official `isImageFile`.
bool isImageFile(String path) => _imageExtensions.contains(fileExtension(path));

/// Cap `getImageSrc` is empty for `.svg`, so SVG is read as text.
bool isRasterPreviewImage(String path) => isImageFile(path) && fileExtension(path) != 'svg';

const mobileFilePreviewCharLimit = 250000;

/// Official `isHtmlFile` (`packages/ui/src/lib/toolHelpers.ts`).
bool isHtmlFile(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return false;
  final slash = trimmed.replaceAll('\\', '/');
  final name = slash.split('/').last.toLowerCase();
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  final ext = name.substring(dot + 1);
  return ext == 'html' || ext == 'htm';
}

String fileNameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  if (normalized.isEmpty || normalized == '/') return normalized.isEmpty ? '/' : normalized;
  return normalized.split('/').where((part) => part.isNotEmpty).last;
}

/// Official `shouldHandIframePanToSheet`: downward pan only at the top.
bool shouldHandPreviewPanToSheet(double scrollTop, double deltaY) {
  return scrollTop.isFinite && deltaY.isFinite && scrollTop <= 1 && deltaY > 0;
}

final _htmlPathToken = RegExp(
  r'(?<![\w`/])((?:\.{1,2}/)?[\w./-]+\.html?)(?![\w./])',
  caseSensitive: false,
);

/// Underline bare HTML/HTM paths in chat Markdown, matching official mobile.
String linkHtmlFileReferences(String text) {
  return text.replaceAllMapped(_htmlPathToken, (match) {
    final path = match[1]!;
    final start = match.start;
    if (start > 0 && text[start - 1] == '[') return path;
    if (start >= 2 && text.substring(start - 2, start) == '](') return path;
    return '[$path]($path)';
  });
}
