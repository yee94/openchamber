import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

class ScheduledTabScreen extends StatelessWidget {
  const ScheduledTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'tabs.scheduled'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, 'scheduled.empty.title'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(t(context, 'scheduled.empty.description')),
          ],
        ),
      ),
    );
  }
}
