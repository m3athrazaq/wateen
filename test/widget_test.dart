import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wateen/app.dart';
import 'package:wateen/state/app_controller.dart';
import 'package:wateen/ui/about_screen.dart';
import 'package:wateen/ui/body_age_screen.dart';
import 'package:wateen/ui/health_monitor_screen.dart';
import 'package:wateen/ui/journal_screen.dart';
import 'package:wateen/ui/onboarding_screen.dart';
import 'package:wateen/ui/recovery_screen.dart';
import 'package:wateen/ui/settings_screen.dart';
import 'package:wateen/ui/sleep_screen.dart';
import 'package:wateen/ui/strain_screen.dart';
import 'package:wateen/ui/stress_screen.dart';
import 'package:wateen/ui/today_screen.dart';
import 'package:wateen/ui/trends_screen.dart';

Future<AppController> _demoController(String language) async {
  SharedPreferences.setMockInitialValues({
    'settings.v1': jsonEncode({
      'language': language,
      'sex': 'male',
      'birthYear': 1991,
      'sleepNeedBaseMin': 450,
      'wakeTimeMin': 390,
      'dataMode': 'demo',
      'onboarded': true,
    }),
  });
  final c = await AppController.load();
  await c.connect(c.settings.dataMode);
  return c;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, Widget page) async {
  final nav = Navigator.of(tester.element(find.byType(TodayScreen)));
  nav.push(MaterialPageRoute<void>(builder: (_) => page));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  expect(tester.takeException(), isNull);
  // Scroll to the end to lay out every section.
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    await tester.drag(scrollables.first, const Offset(0, -3000));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  }
  nav.pop();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  for (final lang in ['ar', 'en']) {
    testWidgets('every screen renders with demo data ($lang)', (tester) async {
      _phone(tester);
      final c = await tester.runAsync(() => _demoController(lang));
      expect(c, isNotNull);
      expect(c!.metrics, isNotEmpty);
      await tester.pumpWidget(WateenApp(controller: c));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      final day = c.latest!.date;
      await _open(tester, RecoveryScreen(day: day));
      await _open(tester, SleepScreen(day: day));
      await _open(tester, StrainScreen(day: day));
      await _open(tester, StressScreen(day: day));
      await _open(tester, HealthMonitorScreen(day: day));
      await _open(tester, const BodyAgeScreen());
      await _open(tester, const SettingsScreen());
      await _open(tester, const MethodScreen());
      await _open(tester, const PrivacyScreen());
      await _open(tester, const AboutScreen());

      // Tabs.
      for (final icon in [Icons.show_chart, Icons.edit_note_outlined, Icons.more_horiz]) {
        await tester.tap(find.byIcon(icon));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(TrendsScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(JournalScreen, skipOffstage: false), findsOneWidget);
    });
  }

  testWidgets('onboarding renders', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    final c = await tester.runAsync(() => AppController.load());
    await tester.pumpWidget(WateenApp(controller: c!));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
