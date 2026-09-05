import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_controller.dart';
import 'features/connect/connect_screen.dart';
import 'features/shell/tab_scaffold.dart';
import 'features/splash/splash_screen.dart';
import 'l10n/app_strings.dart';
import 'theme/app_theme.dart';

class OpenChamberApp extends StatefulWidget {
  const OpenChamberApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<OpenChamberApp> createState() => _OpenChamberAppState();
}

class _OpenChamberAppState extends State<OpenChamberApp> with WidgetsBindingObserver {
  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    controller.setAppVisible(state == AppLifecycleState.resumed);
  }

  @override
  void didChangePlatformBrightness() {
    if (controller.themeMode == ThemeMode.system) {
      setState(() {});
    }
  }

  Brightness get _resolvedBrightness {
    return resolveOcBrightness(
      controller.themeMode,
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final strings = AppStrings.of(controller.locale);
        final useCupertino = defaultTargetPlatform == TargetPlatform.iOS;
        final home = _phaseHome(controller);
        final brightness = _resolvedBrightness;
        final material = materialTheme(brightness);

        Widget app;
        const delegates = <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ];
        if (useCupertino) {
          app = Theme(
            data: material,
            child: CupertinoApp(
              debugShowCheckedModeBanner: false,
              locale: controller.locale,
              supportedLocales: AppStrings.supported,
              localizationsDelegates: delegates,
              theme: cupertinoTheme(brightness),
              builder: (context, child) => Theme(data: material, child: child ?? const SizedBox.shrink()),
              home: home,
            ),
          );
        } else {
          app = MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: controller.locale,
            supportedLocales: AppStrings.supported,
            localizationsDelegates: delegates,
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
