import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/app_controller.dart';
import 'features/connect/connect_screen.dart';
import 'features/shell/tab_scaffold.dart';
import 'features/splash/splash_screen.dart';
import 'l10n/app_strings.dart';
import 'theme/app_theme.dart';

class OpenChamberApp extends StatelessWidget {
  const OpenChamberApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final strings = AppStrings.of(controller.locale);
        final useCupertino = defaultTargetPlatform == TargetPlatform.iOS;
        final home = _phaseHome(controller);

        Widget app;
        if (useCupertino) {
          app = CupertinoApp(
            debugShowCheckedModeBanner: false,
            locale: controller.locale,
            supportedLocales: AppStrings.supported,
            theme: cupertinoTheme(
              controller.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
            ),
            home: home,
          );
        } else {
          app = MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: controller.locale,
            supportedLocales: AppStrings.supported,
            theme: materialTheme(Brightness.light),
            darkTheme: materialTheme(Brightness.dark),
            themeMode: controller.themeMode,
            home: home,
          );
        }

        return StringsScope(strings: strings, child: app);
      },
    );
  }

  Widget _phaseHome(AppController controller) {
    switch (controller.phase) {
      case AppPhase.splash:
        return SplashScreen(controller: controller);
      case AppPhase.connect:
        return ConnectScreen(controller: controller);
      case AppPhase.shell:
        return MobileTabScaffold(controller: controller);
    }
  }
}
