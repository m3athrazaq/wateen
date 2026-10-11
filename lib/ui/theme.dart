import 'package:flutter/material.dart';

import '../models/metrics.dart';
import '../models/raw.dart';

/// Wateen palette: indigo night, wool ivory, and Sadu-weaving dyes used only
/// where colour carries meaning.
class WColors {
  static const night = Color(0xFF0C0F17);
  static const surface = Color(0xFF141925);
  static const surfaceHigh = Color(0xFF1B2131);
  static const line = Color(0xFF242B3B);
  static const ivory = Color(0xFFEFE9DE);
  static const ash = Color(0xFF959CAB);
  static const faint = Color(0xFF5D6577);

  static const madder = Color(0xFFD1453B);
  static const saffron = Color(0xFFE9A23B);
  static const palm = Color(0xFF46B07A);
  static const indigo = Color(0xFF7484FF);
  static const lavender = Color(0xFFA48FF2);
  static const stress = Color(0xFFD1453B);
  static const calm = Color(0xFF4FB3BF);

  static Color recovery(int? r) => r == null ? faint : recoveryZone(zoneOf(r));

  static Color recoveryZone(RecoveryZone z) => switch (z) {
        RecoveryZone.green => palm,
        RecoveryZone.yellow => saffron,
        RecoveryZone.red => madder,
      };

  static const List<Color> zones = [
    Color(0xFF3A4254),
    Color(0xFF6FA8FF),
    Color(0xFF47C6B5),
    Color(0xFF9BCB54),
    Color(0xFFE9A23B),
    Color(0xFFD1453B),
  ];

  static Color stage(SleepStage s) => switch (s) {
        SleepStage.awake || SleepStage.outOfBed => const Color(0xFFE9A23B),
        SleepStage.rem => const Color(0xFF7FC4F5),
        SleepStage.light || SleepStage.asleep || SleepStage.session => const Color(0xFF8C82F0),
        SleepStage.deep => const Color(0xFF5544C9),
        SleepStage.inBed => const Color(0xFF3A4254),
      };

  static Color stressLevel(double? v) {
    if (v == null) return faint;
    if (v < 1) return calm;
    if (v < 2) return saffron;
    return stress;
  }
}

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: WColors.ivory,
    onPrimary: WColors.night,
    secondary: WColors.indigo,
    onSecondary: WColors.night,
    error: WColors.madder,
    onError: WColors.ivory,
    surface: WColors.night,
    onSurface: WColors.ivory,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Plex',
    scaffoldBackgroundColor: WColors.night,
  );
  final text = base.textTheme.apply(bodyColor: WColors.ivory, displayColor: WColors.ivory, fontFamily: 'Plex');
  return base.copyWith(
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: WColors.night,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Plex', fontSize: 20, fontWeight: FontWeight.w600, color: WColors.ivory),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: WColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: WColors.surfaceHigh,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontFamily: 'Plex',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? WColors.ivory : WColors.ash,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? WColors.ivory : WColors.ash,
            size: 24,
          )),
    ),
    dividerTheme: const DividerThemeData(color: WColors.line, thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(iconColor: WColors.ash, textColor: WColors.ivory),
    sliderTheme: const SliderThemeData(
      activeTrackColor: WColors.ivory,
      inactiveTrackColor: WColors.line,
      thumbColor: WColors.ivory,
      overlayColor: Color(0x22EFE9DE),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? WColors.night : WColors.ash),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? WColors.palm : WColors.surfaceHigh),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: WColors.ivory,
        foregroundColor: WColors.night,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontFamily: 'Plex', fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: WColors.ivory,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: WColors.line),
        textStyle: const TextStyle(fontFamily: 'Plex', fontSize: 16, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: WColors.ivory,
        textStyle: const TextStyle(fontFamily: 'Plex', fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? WColors.surfaceHigh : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? WColors.ivory : WColors.ash),
        side: WidgetStateProperty.all(const BorderSide(color: WColors.line)),
        textStyle: WidgetStateProperty.all(const TextStyle(fontFamily: 'Plex', fontSize: 13)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: WColors.surface,
      selectedColor: WColors.surfaceHigh,
      side: const BorderSide(color: WColors.line),
      labelStyle: const TextStyle(fontFamily: 'Plex', fontSize: 13, color: WColors.ivory),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      showCheckmark: false,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: WColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: WColors.surface, surfaceTintColor: Colors.transparent),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: WColors.surfaceHigh,
      contentTextStyle: TextStyle(fontFamily: 'Plex', color: WColors.ivory),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: WColors.ivory),
  );
}

/// Text styles used across screens.
class WText {
  static const _f = 'Plex';
  static const tabular = [FontFeature.tabularFigures()];

  static const hero = TextStyle(fontFamily: _f, fontSize: 56, fontWeight: FontWeight.w700, height: 1.0, fontFeatures: tabular);
  static const big = TextStyle(fontFamily: _f, fontSize: 32, fontWeight: FontWeight.w700, height: 1.1, fontFeatures: tabular);
  static const number = TextStyle(fontFamily: _f, fontSize: 22, fontWeight: FontWeight.w600, height: 1.15, fontFeatures: tabular);
  static const title = TextStyle(fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w600, height: 1.35);
  static const body = TextStyle(fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w400, height: 1.55, color: WColors.ivory);
  static const bodyDim = TextStyle(fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w400, height: 1.55, color: WColors.ash);
  static const label = TextStyle(fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w500, height: 1.3, color: WColors.ash);
  static const small = TextStyle(fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w400, height: 1.3, color: WColors.faint);
}
