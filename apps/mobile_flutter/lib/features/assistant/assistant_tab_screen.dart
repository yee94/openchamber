import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

class AssistantTabScreen extends StatelessWidget {
  const AssistantTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'tabs.assistant'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, 'assistant.empty.title'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(t(context, 'assistant.empty.description')),
          ],
        ),
      ),
    );
  }
}
