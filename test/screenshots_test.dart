// Renders the main screens with the real fonts to PNG files for review.
// Runs only when WATEEN_SHOTS points to an output folder (set in CI).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wateen/l10n/strings.dart';
import 'package:wateen/state/app_controller.dart';
import 'package:wateen/ui/body_age_screen.dart';
import 'package:wateen/ui/health_monitor_screen.dart';
import 'package:wateen/ui/journal_screen.dart';
import 'package:wateen/ui/more_screen.dart';
import 'package:wateen/ui/onboarding_screen.dart';
import 'package:wateen/ui/recovery_screen.dart';
import 'package:wateen/ui/settings_screen.dart';
import 'package:wateen/ui/shell.dart';
import 'package:wateen/ui/sleep_screen.dart';
import 'package:wateen/ui/strain_screen.dart';
import 'package:wateen/ui/stress_screen.dart';
import 'package:wateen/ui/theme.dart';
import 'package:wateen/ui/today_screen.dart';
import 'package:wateen/ui/trends_screen.dart';
import 'package:wateen/util/clock.dart';

final String? _out = Platform.environment['WATEEN_SHOTS'];
const double _dpr = 1.5;
final List<String> _problems = [];

Future<ByteData> _bytes(String path) async => ByteData.sublistView(await File(path).readAsBytes());

Future<void> _loadFonts() async {
  final plex = FontLoader('Plex');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    plex.addFont(_bytes('assets/fonts/IBMPlexSansArabic-$w.ttf'));
  }
  await plex.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(_bytes(icons.path));
      await loader.load();
    } else {
      _problems.add('MaterialIcons font not found under $root');
    }
  } else {
    _problems.add('FLUTTER_ROOT not set; icons render as boxes');
  }
}

Future<AppController> _controller(String language, {bool demo = true}) async {
  SharedPreferences.setMockInitialValues(demo
      ? {
          'settings.v1': jsonEncode({
            'language': language,
            'sex': 'male',
            'birthYear': 1991,
            'sleepNeedBaseMin': 450,
            'wakeTimeMin': 390,
            'dataMode': 'demo',
            'onboarded': true,
          }),
        }
      : {
          'settings.v1': jsonEncode({'language': language}),
        });
  final c = await AppController.load();
  if (demo) await c.connect(c.settings.dataMode);
  return c;
}

Widget _host(AppController c, Widget home) => AppScope(
      controller: c,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: c.locale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );

Future<void> _shot(
  WidgetTester tester,
  AppController c,
  Widget page,
  String name, {
  double height = 844,
  Future<void> Function()? before,
}) async {
  tester.view.physicalSize = Size(390 * _dpr, height * _dpr);
  tester.view.devicePixelRatio = _dpr;
  final key = GlobalKey();
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(RepaintBoundary(key: key, child: _host(c, page)));
  await tester.pump(const Duration(seconds: 2));
  if (before != null) {
    await before();
    await tester.pump(const Duration(seconds: 1));
  }
  // Decode images (the app mark) for real before capturing.
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump(const Duration(milliseconds: 200));
  final error = tester.takeException();
  if (error != null) _problems.add('$name: $error');
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('screenshots', (tester) async {
    Directory(_out!).createSync(recursive: true);
    await tester.runAsync(_loadFonts);
    addTearDown(tester.view.reset);
    // An evening view: a full day of strain, stress and tonight's bedtime.
    final real = DateTime.now();
    setClockForTesting(DateTime(real.year, real.month, real.day, 21, 30));
    addTearDown(() => setClockForTesting(null));

    for (final lang in ['ar', 'en']) {
      final c = (await tester.runAsync(() => _controller(lang)))!;
      final day = c.latest!.date;
      final s = S(lang == 'ar');
      final full = lang == 'ar';

      await _shot(tester, c, const HomeShell(), '${lang}_01_home');
      await _shot(tester, c, TodayScreen(onOpenJournal: () {}), '${lang}_02_today_full', height: 2000);
      await _shot(tester, c, SleepScreen(day: day), '${lang}_04_sleep', height: 2500);
      await _shot(tester, c, const TrendsScreen(), '${lang}_07_trends', height: 1300);
      if (full) {
        await _shot(tester, c, RecoveryScreen(day: day), '${lang}_03_recovery', height: 1500);
        await _shot(tester, c, StrainScreen(day: day), '${lang}_05_strain', height: 2400);
        await _shot(tester, c, StressScreen(day: day), '${lang}_06_stress', height: 1400);
        await _shot(tester, c, const JournalScreen(), '${lang}_08_journal', height: 1500);
        await _shot(tester, c, const JournalScreen(), '${lang}_09_journal_impact',
            height: 1500, before: () => tester.tap(find.text(s.journalImpact)));
        await _shot(tester, c, const MoreScreen(), '${lang}_10_more');
        await _shot(tester, c, HealthMonitorScreen(day: day), '${lang}_11_health', height: 1300);
        await _shot(tester, c, const BodyAgeScreen(), '${lang}_12_body_age', height: 1300);
        await _shot(tester, c, const SettingsScreen(), '${lang}_13_settings', height: 1800);
      }
      final o = (await tester.runAsync(() => _controller(lang, demo: false)))!;
      await _shot(tester, o, const OnboardingScreen(), '${lang}_00_onboarding');
    }

    if (_problems.isNotEmpty) {
      final text = _problems.join('\n').replaceAll('%', '%25').replaceAll('\r', '').replaceAll('\n', '%0A');
      // ignore: avoid_print
      print('::warning title=Screenshot issues::$text');
      File('$_out/problems.txt').writeAsStringSync(_problems.join('\n\n'));
    }
  }, skip: _out == null, timeout: const Timeout(Duration(minutes: 8)));
}
