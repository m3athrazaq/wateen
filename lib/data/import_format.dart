import 'dart:convert';

import '../models/journal.dart';
import '../models/raw.dart';
import '../util/dates.dart';

/// The file is not a Wateen data file, or it holds no usable samples.
class ImportFormatException implements Exception {
  final String message;
  ImportFormatException(this.message);

  @override
  String toString() => 'ImportFormatException: $message';
}

/// A parsed Wateen data file ("format": "wateen-raw").
///
/// Times are epoch seconds. Arrays hold compact rows:
///   heartRate, hrv, restingHr, respiratoryRate, spo2, skinTemp: [t, value]
///   sleep: [start, end, stage, source?]   stage: inBed|asleep|awake|light|core|deep|rem
///   steps: [start, end, count]
///   workouts: {start, end, type, kcal?, distance?}
///   dailySteps / activeEnergy: {"yyyy-mm-dd": number}
///   journal: {"yyyy-mm-dd": {questionId: bool}}
/// With "alignToToday": true every date moves by whole days so the data ends
/// today (never in the future) — handy for test data.
class ImportedData {
  final RawBundle bundle;
  final Map<String, JournalEntry> journal;
  final DateTime first;
  final DateTime last;
  final int shiftDays;

  const ImportedData({
    required this.bundle,
    required this.journal,
    required this.first,
    required this.last,
    required this.shiftDays,
  });

  int get dayCount => daysBetween(first, last) + 1;

  static ImportedData parse(String text, {required DateTime now}) {
    try {
      return _parse(text, now);
    } on ImportFormatException {
      rethrow;
    } catch (e) {
      throw ImportFormatException('invalid content: $e');
    }
  }

  static ImportedData _parse(String text, DateTime now) {
    Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      throw ImportFormatException('not JSON');
    }
    if (root is! Map) throw ImportFormatException('not an object');
    if (root['format'] != 'wateen-raw') throw ImportFormatException('unknown format');
    final version = root['version'];
    if (version is num && version > 1) throw ImportFormatException('newer version $version');

    final heartRate = _pairs(root['heartRate']);
    final hrv = _pairs(root['hrv']);
    final restingHr = _pairs(root['restingHr']);
    final respiratory = _pairs(root['respiratoryRate']);
    final spo2 = _pairs(root['spo2']);
    final temperature = _pairs(root['skinTemp']);
    final sleep = <SleepSegment>[];
    for (final r in _list(root['sleep'])) {
      if (r is List && r.length >= 3 && r[0] is num && r[1] is num && r[2] is String) {
        final source = r.length > 3 && r[3] is String ? r[3] as String : 'import';
        final start = _time(r[0] as num);
        final end = _time(r[1] as num);
        if (end.isAfter(start)) sleep.add(SleepSegment(start, end, _stage(r[2] as String), source));
      }
    }
    final workouts = <WorkoutRecord>[];
    for (final w in _list(root['workouts'])) {
      if (w is Map && w['start'] is num && w['end'] is num) {
        workouts.add(WorkoutRecord(
          start: _time(w['start'] as num),
          end: _time(w['end'] as num),
          type: (w['type'] as String?) ?? 'OTHER',
          kcal: (w['kcal'] as num?)?.toDouble(),
          distanceM: (w['distance'] as num?)?.toDouble(),
        ));
      }
    }
    final steps = <StepSample>[];
    for (final r in _list(root['steps'])) {
      if (r is List && r.length >= 3 && r[0] is num && r[1] is num && r[2] is num) {
        steps.add(StepSample(_time(r[0] as num), _time(r[1] as num), (r[2] as num).toDouble()));
      }
    }
    final dailySteps = <String, int>{};
    _dayMap(root['dailySteps']).forEach((k, v) => dailySteps[k] = v.round());
    final activeEnergy = <String, double>{};
    _dayMap(root['activeEnergy']).forEach((k, v) => activeEnergy[k] = v.toDouble());
    final journal = <String, JournalEntry>{};
    final j = root['journal'];
    if (j is Map) {
      j.forEach((k, v) {
        final day = _day(k);
        if (day == null || v is! Map) return;
        final answers = <String, bool>{};
        v.forEach((q, a) {
          if (q is String && a is bool) answers[q] = a;
        });
        if (answers.isNotEmpty) journal[dayKey(day)] = JournalEntry(day, answers);
      });
    }

    // Data range.
    DateTime? first;
    DateTime? last;
    void see(DateTime a, [DateTime? b]) {
      final end = b ?? a;
      if (first == null || a.isBefore(first!)) first = a;
      if (last == null || end.isAfter(last!)) last = end;
    }

    for (final list in [heartRate, hrv, restingHr, respiratory, spo2, temperature]) {
      for (final v in list) {
        see(v.time);
      }
    }
    for (final s in sleep) {
      see(s.start, s.end);
    }
    for (final w in workouts) {
      see(w.start, w.end);
    }
    for (final s in steps) {
      see(s.start, s.end);
    }
    if (first == null || last == null || (heartRate.isEmpty && sleep.isEmpty)) {
      throw ImportFormatException('no heart rate or sleep samples');
    }

    var shift = 0;
    if (root['alignToToday'] == true) {
      shift = daysBetween(last!, now);
      while (last!.add(Duration(days: shift)).isAfter(now)) {
        shift -= 1;
      }
    }

    if (shift != 0) {
      final by = Duration(days: shift);
      DateTime mv(DateTime t) => t.add(by);
      List<TimedValue> mvPairs(List<TimedValue> l) => [for (final v in l) TimedValue(mv(v.time), v.value)];
      String mvKey(String k) => dayKey(addDays(parseDayKey(k), shift));
      return ImportedData(
        bundle: RawBundle(
          start: mv(first!),
          end: mv(last!),
          heartRate: mvPairs(heartRate),
          hrv: mvPairs(hrv),
          hrvIsRmssd: root['hrvType'] == 'rmssd',
          restingHr: mvPairs(restingHr),
          respiratory: mvPairs(respiratory),
          spo2: mvPairs(spo2),
          temperature: mvPairs(temperature),
          sleep: [for (final s in sleep) SleepSegment(mv(s.start), mv(s.end), s.stage, s.source)],
          workouts: [
            for (final w in workouts)
              WorkoutRecord(start: mv(w.start), end: mv(w.end), type: w.type, kcal: w.kcal, distanceM: w.distanceM),
          ],
          stepSamples: [for (final s in steps) StepSample(mv(s.start), mv(s.end), s.count)],
          stepsByDay: dailySteps.map((k, v) => MapEntry(mvKey(k), v)),
          activeKcalByDay: activeEnergy.map((k, v) => MapEntry(mvKey(k), v)),
        )..sortAll(),
        journal: journal.map((k, v) => MapEntry(mvKey(k), JournalEntry(addDays(v.date, shift), v.answers))),
        first: mv(first!),
        last: mv(last!),
        shiftDays: shift,
      );
    }

    return ImportedData(
      bundle: RawBundle(
        start: first!,
        end: last!,
        heartRate: heartRate,
        hrv: hrv,
        hrvIsRmssd: root['hrvType'] == 'rmssd',
        restingHr: restingHr,
        respiratory: respiratory,
        spo2: spo2,
        temperature: temperature,
        sleep: sleep,
        workouts: workouts,
        stepSamples: steps,
        stepsByDay: dailySteps,
        activeKcalByDay: activeEnergy,
      )..sortAll(),
      journal: journal,
      first: first!,
      last: last!,
      shiftDays: 0,
    );
  }

  /// Samples between [start] and [end] in the shape the health sources return.
  RawBundle slice(DateTime start, DateTime end) {
    bool inRange(DateTime t) => !t.isBefore(start) && !t.isAfter(end);
    List<TimedValue> pick(List<TimedValue> l) => [for (final v in l) if (inRange(v.time)) v];
    bool dayInRange(String k) {
      final d = parseDayKey(k);
      return !d.isBefore(dayOf(start)) && !d.isAfter(dayOf(end));
    }

    return RawBundle(
      start: start,
      end: end,
      heartRate: pick(bundle.heartRate),
      hrv: pick(bundle.hrv),
      hrvIsRmssd: bundle.hrvIsRmssd,
      restingHr: pick(bundle.restingHr),
      respiratory: pick(bundle.respiratory),
      spo2: pick(bundle.spo2),
      temperature: pick(bundle.temperature),
      sleep: [for (final s in bundle.sleep) if (s.end.isAfter(start) && !s.end.isAfter(end)) s],
      workouts: [for (final w in bundle.workouts) if (!w.start.isBefore(start) && !w.end.isAfter(end)) w],
      stepSamples: [for (final s in bundle.stepSamples) if (!s.start.isBefore(start) && !s.end.isAfter(end)) s],
      stepsByDay: {
        for (final e in bundle.stepsByDay.entries)
          if (dayInRange(e.key)) e.key: e.value,
      },
      activeKcalByDay: {
        for (final e in bundle.activeKcalByDay.entries)
          if (dayInRange(e.key)) e.key: e.value,
      },
    );
  }
}

DateTime _time(num secs) => DateTime.fromMillisecondsSinceEpoch((secs * 1000).round());

List<dynamic> _list(Object? v) => v is List ? v : const [];

List<TimedValue> _pairs(Object? v) {
  final out = <TimedValue>[];
  for (final r in _list(v)) {
    if (r is List && r.length >= 2 && r[0] is num && r[1] is num) {
      out.add(TimedValue(_time(r[0] as num), (r[1] as num).toDouble()));
    }
  }
  return out;
}

DateTime? _day(Object? k) {
  if (k is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(k);
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

Map<String, num> _dayMap(Object? v) {
  final out = <String, num>{};
  if (v is Map) {
    v.forEach((k, n) {
      final d = _day(k);
      if (d != null && n is num) out[dayKey(d)] = n;
    });
  }
  return out;
}

SleepStage _stage(String s) {
  switch (s) {
    case 'core':
      return SleepStage.light;
    case 'in_bed':
      return SleepStage.inBed;
    default:
      return sleepStageFromName(s);
  }
}

/// Reads a file's bytes as UTF-8 text (with or without a byte-order mark).
String decodeImportBytes(List<int> bytes) {
  var b = bytes;
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) b = b.sublist(3);
  return utf8.decode(b);
}
