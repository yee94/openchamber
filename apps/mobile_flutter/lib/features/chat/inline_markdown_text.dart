import 'package:flutter/material.dart';

import 'chat_markdown_body.dart';

/// Back-compat wrapper. Chat bodies use [ChatMarkdownBody] directly.
class InlineMarkdownText extends StatelessWidget {
  const InlineMarkdownText({
    super.key,
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: style ?? DefaultTextStyle.of(context).style,
      child: ChatMarkdownBody(text: text),
    );
  }
}
