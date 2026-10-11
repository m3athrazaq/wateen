import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../state/app_controller.dart';
import 'format.dart';

extension WateenContext on BuildContext {
  AppController get app => AppScope.of(this);
  S get s => S(AppScope.of(this).settings.isArabic);
  Fmt get fmt => Fmt(AppScope.of(this).settings.isArabic);

  Future<T?> push<T>(Widget page) => Navigator.of(this).push<T>(MaterialPageRoute<T>(builder: (_) => page));
}
