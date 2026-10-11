import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/app_controller.dart';
import 'ui/onboarding_screen.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

class WateenApp extends StatelessWidget {
  final AppController controller;
  const WateenApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: Builder(builder: (context) {
        final app = AppScope.of(context);
        return MaterialApp(
          title: 'Wateen',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: app.locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: app.settings.onboarded ? const HomeShell() : const OnboardingScreen(),
        );
      }),
    );
  }
}
