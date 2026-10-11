import 'dart:io' show File, Platform;
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/demo_source.dart';
import '../data/health_source.dart';
import '../data/import_format.dart';
import '../data/imported_source.dart';
import '../data/platform_source.dart';
import '../data/store.dart';
import '../engine/body_age.dart';
import '../engine/extract.dart';
import '../engine/insights.dart';
import '../engine/score.dart';
import '../models/day.dart';
import '../models/journal.dart';
import '../models/metrics.dart';
import '../models/settings.dart';
import '../util/dates.dart';
import '../util/stats.dart';
import '../util/clock.dart';

/// Result of choosing a data file to import.
class ImportOutcome {
  final bool cancelled;
  final bool ok;
  final int days;
  const ImportOutcome._(this.cancelled, this.ok, this.days);
  const ImportOutcome.cancelled() : this._(true, false, 0);
  const ImportOutcome.failed() : this._(false, false, 0);
  const ImportOutcome.done(int days) : this._(false, true, days);
}

class AppController extends ChangeNotifier {
  static const int keepDays = 120;
  static const int detailDays = 14;
  static const int firstSyncDays = 60;

  final Store store;
  UserSettings settings;
  Map<String, DayInputs> _inputs;
  Map<String, JournalEntry> journal;
  List<DayMetrics> metrics = const [];
  DateTime? lastSync;
  bool loading = false;
  String? error;
  List<String> missingTypes = const [];
  ConnectStatus? connectStatus;

  final PlatformHealthSource _platform = PlatformHealthSource();
  final DemoHealthSource _demo = DemoHealthSource();
  final ImportedHealthSource _imported = ImportedHealthSource();

  AppController._(this.store, this.settings, this._inputs, this.journal, this.lastSync);

  static Future<AppController> load() async {
    final store = await Store.open();
    final c = AppController._(
      store,
      store.loadSettings(),
      store.loadInputs(),
      store.loadJournal(),
      store.loadLastSync(),
    );
    c._rescore();
    return c;
  }

  HealthSource get _source => switch (settings.dataMode) {
        DataMode.demo => _demo,
        DataMode.imported => _imported,
        _ => _platform,
      };

  bool get isDemo => settings.dataMode == DataMode.demo;

  bool get isImported => settings.dataMode == DataMode.imported;

  bool get isIOS => !kIsWeb && Platform.isIOS;

  Locale get locale => Locale(settings.language);

  // ------------------------------------------------------------------ data

  DayMetrics? metricsFor(DateTime day) {
    final k = dayKey(day);
    for (var i = metrics.length - 1; i >= 0; i--) {
      if (metrics[i].inputs.key == k) return metrics[i];
    }
    return null;
  }

  /// Latest day that has data (today if it already has some).
  DayMetrics? get latest {
    for (var i = metrics.length - 1; i >= 0; i--) {
      if (metrics[i].inputs.hasAnyData) return metrics[i];
    }
    return null;
  }

  List<DayMetrics> lastDays(int n, {DateTime? until}) {
    final end = dayOf(until ?? clockNow());
    final start = addDays(end, -(n - 1));
    return metrics.where((m) => !m.date.isBefore(start) && !m.date.isAfter(end)).toList();
  }

  List<JournalInsight> get insights => journalInsights(journal, metrics);

  BodyAgeResult? get bodyAge => estimateBodyAge(metrics, settings, clockNow());

  // --------------------------------------------------------------- actions

  Future<ConnectStatus> connect(DataMode mode) async {
    final previous = settings.dataMode;
    if (previous != mode) {
      if (previous == DataMode.demo) _removeDemoJournal();
      if (previous == DataMode.imported) await _removeImportedJournal();
      _inputs = {};
      lastSync = null;
      metrics = const [];
    }
    settings.dataMode = mode;
    await store.saveSettings(settings);
    final status = await _source.connect();
    connectStatus = status;
    if (status == ConnectStatus.connected) {
      if (mode == DataMode.demo) _seedDemoJournal();
      if (mode == DataMode.imported) await _mergeImportedJournal();
      await refresh(full: true);
    }
    notifyListeners();
    return status;
  }

  /// Lets the person pick a Wateen data file (JSON) and uses it as the source.
  Future<ImportOutcome> importDataFile() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (picked == null || picked.files.isEmpty) return const ImportOutcome.cancelled();
    final file = picked.files.single;
    List<int>? bytes = file.bytes;
    if (bytes == null && file.path != null) bytes = await File(file.path!).readAsBytes();
    if (bytes == null) return const ImportOutcome.failed();
    final String text;
    final ImportedData data;
    try {
      text = decodeImportBytes(bytes);
      data = ImportedData.parse(text, now: clockNow());
    } catch (e) {
      debugPrint('Wateen: import failed: $e');
      return const ImportOutcome.failed();
    }
    // A new file replaces the previous import and its journal answers.
    if (isImported) await _removeImportedJournal();
    await ImportStore.write(text);
    _imported.clearCache();
    _inputs = {};
    lastSync = null;
    metrics = const [];
    final status = await connect(DataMode.imported);
    if (status != ConnectStatus.connected) return const ImportOutcome.failed();
    return ImportOutcome.done(data.dayCount);
  }

  Future<void> installHealthConnect() => _platform.installHealthConnect();

  Future<void> refresh({bool full = false}) async {
    if (loading || settings.dataMode == DataMode.none) return;
    // Imported test data moves with the calendar, so it is always recomputed.
    if (isImported) full = true;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final now = clockNow();
      final today = dayOf(now);
      int days;
      if (full || _inputs.isEmpty || lastSync == null) {
        days = firstSyncDays;
      } else {
        days = math.min(firstSyncDays, math.max(3, daysBetween(lastSync!, now) + 2));
      }
      final firstDay = addDays(today, -(days - 1));
      final fetchStart = addDays(firstDay, -1).add(const Duration(hours: 12));
      final raw = await _source.fetch(fetchStart, now);
      missingTypes = raw.missing;

      final firstSync = full || _inputs.isEmpty;
      var rest = _restReference(_inputs.values);
      var maxHr = _maxHr(_inputs.values, now);
      var fresh = Extractor(restHr: rest, maxHr: maxHr, sex: settings.sex, now: now).extract(raw, firstDay, today);
      if (firstSync) {
        // Learn resting and peak heart rate from this data, then extract again.
        final rest2 = _restReference(fresh.values);
        final max2 = _maxHr(fresh.values, now);
        if ((rest2 - rest).abs() > 0.5 || (max2 - maxHr).abs() > 0.5) {
          rest = rest2;
          maxHr = max2;
          fresh = Extractor(restHr: rest, maxHr: maxHr, sex: settings.sex, now: now).extract(raw, firstDay, today);
        }
      }
      if (full) _inputs.clear();
      _inputs.addAll(fresh);
      _prune(today);
      _rescore();
      lastSync = now;
      await store.saveInputs(_inputs);
      await store.saveLastSync(now);
    } catch (e, st) {
      debugPrint('Wateen: refresh failed: $e\n$st');
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Resting heart rate used for load: median of the nights, else 60.
  double _restReference(Iterable<DayInputs> days) {
    final recent = days.where((d) => d.rhr != null).map((d) => d.rhr!).toList();
    return medianOf(recent) ?? 60.0;
  }

  /// Max heart rate: user value, or the higher of formula and observed peak.
  double _maxHr(Iterable<DayInputs> days, DateTime now) {
    final formula = settings.maxHrAt(now).toDouble();
    if (settings.maxHrOverride != null) return formula;
    final peaks = days.where((d) => d.maxHr != null).map((d) => d.maxHr!).toList();
    final observed = percentileOf(peaks, 0.98) ?? 0.0;
    return math.min(220.0, math.max(formula, observed));
  }

  void _prune(DateTime today) {
    final cutoff = addDays(today, -keepDays);
    final detailCut = addDays(today, -detailDays);
    _inputs.removeWhere((k, v) => v.date.isBefore(cutoff));
    for (final k in _inputs.keys.toList()) {
      final v = _inputs[k]!;
      if (v.date.isBefore(detailCut) && (v.hrSeries.isNotEmpty || (v.sleep?.spans.isNotEmpty ?? false))) {
        _inputs[k] = v.lite();
      }
    }
  }

  void _rescore() {
    final list = _inputs.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    metrics = Scorer(settings).score(list);
  }

  /// Drops journal days that still hold exactly the generated demo answers.
  void _removeDemoJournal() {
    final now = clockNow();
    final demo = DemoHealthSource.journalFor(addDays(dayOf(now), -keepDays), dayOf(now));
    journal.removeWhere((k, v) {
      final d = demo[k];
      if (d == null) return false;
      if (d.answers.length != v.answers.length) return false;
      for (final e in d.answers.entries) {
        if (v.answers[e.key] != e.value) return false;
      }
      return true;
    });
    store.saveJournal(journal);
  }

  /// Adds the imported file's journal days that the person has not answered.
  Future<void> _mergeImportedJournal() async {
    final data = await _imported.load();
    if (data == null) return;
    data.journal.forEach((k, v) => journal.putIfAbsent(k, () => v));
    await store.saveJournal(journal);
  }

  /// Drops journal days that still hold exactly the imported answers.
  Future<void> _removeImportedJournal() async {
    ImportedData? data;
    try {
      data = await _imported.load();
    } catch (_) {
      data = null;
    }
    if (data == null) return;
    final imported = data.journal;
    journal.removeWhere((k, v) {
      final d = imported[k];
      if (d == null || d.answers.length != v.answers.length) return false;
      for (final e in d.answers.entries) {
        if (v.answers[e.key] != e.value) return false;
      }
      return true;
    });
    await store.saveJournal(journal);
  }

  void _seedDemoJournal() {
    final now = clockNow();
    final demo = DemoHealthSource.journalFor(addDays(dayOf(now), -firstSyncDays), addDays(dayOf(now), -1));
    demo.forEach((k, v) => journal.putIfAbsent(k, () => v));
    store.saveJournal(journal);
  }

  // -------------------------------------------------------------- settings

  Future<void> updateSettings(void Function(UserSettings s) change, {bool rescore = true}) async {
    change(settings);
    await store.saveSettings(settings);
    if (rescore) _rescore();
    notifyListeners();
  }

  Future<void> setLanguage(String lang) => updateSettings((s) => s.language = lang, rescore: false);

  Future<void> completeOnboarding() => updateSettings((s) => s.onboarded = true, rescore: false);

  Future<void> answerJournal(DateTime day, String id, bool? value) async {
    final k = dayKey(day);
    final entry = journal[k] ?? JournalEntry(dayOf(day), const {});
    journal[k] = entry.withAnswer(id, value);
    await store.saveJournal(journal);
    notifyListeners();
  }

  Future<void> resync() async {
    await store.clearData();
    _inputs = {};
    lastSync = null;
    _rescore();
    notifyListeners();
    await refresh(full: true);
  }

  Future<void> eraseEverything() async {
    await store.clearAll();
    await ImportStore.delete();
    _imported.clearCache();
    settings = UserSettings();
    _inputs = {};
    journal = {};
    lastSync = null;
    metrics = const [];
    notifyListeners();
  }
}

/// Makes the controller available to the widget tree.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
