import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../l10n/app_strings.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.controller.activeInstance;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(context, 'app.name'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator.adaptive(),
            if (active != null) ...[
              const SizedBox(height: 16),
              Text('${t(context, 'splash.connectingTo')} ${active.displayLabel}'),
            ],
          ],
        ),
      ),
    );
  }
}
