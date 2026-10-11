import 'dart:math' as math;

import '../models/journal.dart';
import '../models/raw.dart';
import '../util/dates.dart';
import 'health_source.dart';

/// Deterministic, realistic sample data for trying the app without a watch.
///
/// Each day's behaviours (late caffeine, stress, training, ...) shift the
/// following night and next-morning physiology, so the scores, trends and
/// journal insights all behave like they would with real data.
class DemoHealthSource implements HealthSource {
  static const String watchSource = 'demo.watch';
  static const String phoneSource = 'demo.phone';
  static const double restHr = 53;
  static const double maxHr = 185;

  @override
  Future<ConnectStatus> connect() async => ConnectStatus.connected;

  @override
  Future<RawBundle> fetch(DateTime start, DateTime end) async {
    final b = RawBundle(start: start, end: end, hrvIsRmssd: false);
    for (var d = addDays(dayOf(start), -1); !d.isAfter(dayOf(end)); d = addDays(d, 1)) {
      _night(b, d, start, end);
      _day(b, d, start, end);
    }
    b.sortAll();
    return b;
  }

  /// Journal answers that match the generated behaviour.
  static Map<String, JournalEntry> journalFor(DateTime from, DateTime to) {
    final out = <String, JournalEntry>{};
    for (var d = dayOf(from); !d.isAfter(dayOf(to)); d = addDays(d, 1)) {
      final p = DayPlan.of(d);
      out[dayKey(d)] = JournalEntry(d, {
        'caffeine_late': p.caffeineLate,
        'late_meal': p.lateMeal,
        'screen_bed': p.screenBed,
        'hydrated': p.hydrated,
        'work_stress': p.workStress,
        'reading_bed': p.readingBed,
        'stretching': p.stretching,
        'smoking': p.smoking,
      });
    }
    return out;
  }

  // ---------------------------------------------------------------- night

  void _night(RawBundle b, DateTime d, DateTime from, DateTime to) {
    final n = NightPlan.of(d);
    // Watches save a night after waking, so an unfinished night is not shown.
    if (n.wake.isAfter(to)) return;
    final r = math.Random(_dayNo(d) * 13 + 5);
    bool ok(DateTime t) => !t.isBefore(from) && t.isBefore(to);

    // Phone "in bed" interval (the app must prefer the watch's stages).
    if (ok(n.wake)) {
      b.sleep.add(SleepSegment(n.bed, n.wake.add(const Duration(minutes: 4)), SleepStage.inBed, phoneSource));
    }
    for (final s in n.segments) {
      if (ok(s.end)) b.sleep.add(s);
    }

    final z = DayPlan.of(d).readinessNext;
    final hrBase = 53 - 2.2 * z;
    for (var t = n.sleepStart; t.isBefore(n.wake); t = t.add(Duration(minutes: 4 + r.nextInt(3)))) {
      if (!ok(t)) continue;
      final stage = n.stageAt(t);
      var hr = hrBase + _gauss(r) * 2.2;
      if (stage == SleepStage.rem) hr += 4;
      if (stage == SleepStage.deep) hr -= 2;
      if (stage == SleepStage.awake) hr += 9;
      b.heartRate.add(TimedValue(t, hr));
    }

    final hrv = 52 * math.exp(0.17 * z);
    final asleepSpan = n.wake.difference(n.sleepStart).inMinutes;
    for (var i = 0; i < 5; i++) {
      final t = n.sleepStart.add(Duration(minutes: (asleepSpan * (0.1 + 0.18 * i)).round()));
      if (ok(t)) b.hrv.add(TimedValue(t, hrv * (1 + _gauss(r) * 0.08)));
    }
    for (var i = 0; i < 4; i++) {
      final t = n.sleepStart.add(Duration(minutes: (asleepSpan * (0.15 + 0.2 * i)).round()));
      if (ok(t)) b.respiratory.add(TimedValue(t, 14.6 - 0.25 * z + _gauss(r) * 0.2));
    }
    for (var i = 0; i < 6; i++) {
      final t = n.sleepStart.add(Duration(minutes: (asleepSpan * (0.1 + 0.14 * i)).round()));
      if (ok(t)) b.spo2.add(TimedValue(t, (96.8 + _gauss(r) * 0.6).clamp(93.0, 99.5).toDouble()));
    }
    if (ok(n.sleepStart)) b.temperature.add(TimedValue(n.sleepStart, 35.7 + _gauss(r) * 0.12));
    final rhrDay = dayOf(n.wake);
    final rhrTime = DateTime(rhrDay.year, rhrDay.month, rhrDay.day, 20);
    if (ok(rhrTime)) b.restingHr.add(TimedValue(rhrTime, hrBase + 6 + _gauss(r)));
  }

  // ------------------------------------------------------------------ day

  void _day(RawBundle b, DateTime d, DateTime from, DateTime to) {
    final p = DayPlan.of(d);
    final wake = NightPlan.of(addDays(d, -1)).wake;
    final bed = NightPlan.of(d).bed;
    final r = math.Random(_dayNo(d) * 31 + 7);
    bool ok(DateTime t) => !t.isBefore(from) && t.isBefore(to);
    final zMorning = DayPlan.of(addDays(d, -1)).readinessNext;
    final base = 70 - 1.5 * zMorning;

    // Workout window.
    final DateTime? wStart =
        p.workoutType != null ? DateTime(d.year, d.month, d.day, p.workoutHour, r.nextInt(50)) : null;
    final DateTime? wEnd = wStart?.add(Duration(minutes: p.workoutMin));

    // Walking bouts.
    final bouts = <(DateTime, DateTime)>[];
    final nb = 4 + r.nextInt(5);
    for (var i = 0; i < nb; i++) {
      final s = DateTime(d.year, d.month, d.day, 8 + r.nextInt(12), r.nextInt(60));
      bouts.add((s, s.add(Duration(minutes: 8 + r.nextInt(14)))));
    }
    bool inBout(DateTime t) => bouts.any((x) => !t.isBefore(x.$1) && t.isBefore(x.$2));
    bool inWorkout(DateTime t) {
      final s = wStart;
      final e = wEnd;
      return s != null && e != null && !t.isBefore(s) && t.isBefore(e);
    }

    var steps = 0.0;
    var kcal = 0.0;
    for (var t = wake; t.isBefore(bed); t = t.add(Duration(minutes: 4 + r.nextInt(3)))) {
      if (inWorkout(t)) continue;
      var hr = base + _gauss(r) * 4;
      if (p.workStress && t.hour >= 9 && t.hour < 17) hr += 8;
      if (p.caffeineLate && t.hour >= 15 && t.hour < 21) hr += 4;
      if (inBout(t)) hr = 98 + _gauss(r) * 5;
      if (ok(t)) b.heartRate.add(TimedValue(t, hr));
    }

    // Steps in 15-minute chunks of light movement plus walking bouts.
    for (var t = wake; t.isBefore(bed); t = t.add(const Duration(minutes: 15))) {
      final e = t.add(const Duration(minutes: 15));
      if (inWorkout(t)) continue;
      final walking = bouts.any((x) => x.$1.isBefore(e) && x.$2.isAfter(t));
      final c = walking ? 900 + r.nextInt(500) : 40 + r.nextInt(160);
      if (ok(t)) {
        b.stepSamples.add(StepSample(t, e, c.toDouble()));
        steps += c;
        kcal += c * 0.04;
      }
    }

    if (wStart != null && wEnd != null) {
      final start = wStart;
      final end = wEnd;
      final total = end.difference(start).inSeconds;
      for (var t = start; t.isBefore(end); t = t.add(const Duration(seconds: 10))) {
        final x = t.difference(start).inSeconds / total;
        var frac = p.workoutIntensity;
        if (x < 0.1) frac *= 0.55 + 4.5 * x;
        if (x > 0.9) frac *= 1 - 3 * (x - 0.9);
        if (p.workoutType == 'TRADITIONAL_STRENGTH_TRAINING') {
          frac *= (t.minute % 3 == 0) ? 1.15 : 0.8;
        }
        final hr = restHr + frac * (maxHr - restHr) + _gauss(r) * 3;
        if (ok(t)) b.heartRate.add(TimedValue(t, hr));
      }
      final wKcal = p.workoutMin * (5 + 9 * p.workoutIntensity);
      double? dist;
      if (p.workoutType == 'RUNNING') dist = p.workoutMin * 165.0;
      if (p.workoutType == 'BIKING') dist = p.workoutMin * 450.0;
      if (ok(end)) {
        b.workouts.add(WorkoutRecord(start: start, end: end, type: p.workoutType!, kcal: wKcal, distanceM: dist));
        if (p.workoutType == 'RUNNING') {
          final s = p.workoutMin * 160.0;
          b.stepSamples.add(StepSample(start, end, s));
          steps += s;
        }
        kcal += wKcal;
      }
    }

    if (steps > 0) b.stepsByDay[dayKey(d)] = steps.round();
    if (kcal > 0) b.activeKcalByDay[dayKey(d)] = 260 + kcal;
  }
}

int _dayNo(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

double _gauss(math.Random r) {
  final u1 = math.max(1e-9, r.nextDouble());
  final u2 = r.nextDouble();
  return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
}

/// Behaviour and training for one day (affects that evening's night).
class DayPlan {
  final bool caffeineLate;
  final bool lateMeal;
  final bool screenBed;
  final bool hydrated;
  final bool workStress;
  final bool readingBed;
  final bool stretching;
  final bool smoking;
  final String? workoutType;
  final int workoutMin;
  final int workoutHour;
  final double workoutIntensity;

  /// Asleep hours for the night starting this evening.
  final double sleepHours;

  /// Bedtime shift from 23:15 in minutes.
  final double bedShiftMin;

  /// Readiness of the next morning in standard deviations.
  final double readinessNext;

  const DayPlan._({
    required this.caffeineLate,
    required this.lateMeal,
    required this.screenBed,
    required this.hydrated,
    required this.workStress,
    required this.readingBed,
    required this.stretching,
    required this.smoking,
    required this.workoutType,
    required this.workoutMin,
    required this.workoutHour,
    required this.workoutIntensity,
    required this.sleepHours,
    required this.bedShiftMin,
    required this.readinessNext,
  });

  static final Map<int, DayPlan> _cache = {};

  factory DayPlan.of(DateTime day) => _cache.putIfAbsent(_dayNo(day), () => DayPlan._build(day));

  factory DayPlan._build(DateTime day) {
    final r = math.Random(_dayNo(day) * 7919 + 17);
    final weekday = day.weekday; // Mon=1 .. Sun=7
    final nextIsWeekend = weekday == DateTime.thursday || weekday == DateTime.friday;
    final caffeineLate = r.nextDouble() < 0.3;
    final lateMeal = r.nextDouble() < 0.25;
    final screenBed = r.nextDouble() < 0.5;
    final hydrated = r.nextDouble() < 0.6;
    final workStress = weekday <= DateTime.thursday || weekday == DateTime.sunday
        ? r.nextDouble() < 0.4
        : r.nextDouble() < 0.1;
    final readingBed = r.nextDouble() < 0.35;
    final stretching = r.nextDouble() < 0.3;
    final smoking = r.nextDouble() < 0.12;

    String? type;
    var minutes = 0;
    var intensity = 0.0;
    var hour = 18;
    switch (weekday) {
      case DateTime.saturday:
        type = 'BIKING';
        minutes = 90;
        intensity = 0.62;
        hour = 10;
      case DateTime.sunday:
        type = 'RUNNING';
        minutes = 45;
        intensity = 0.72;
      case DateTime.monday:
      case DateTime.thursday:
        type = 'TRADITIONAL_STRENGTH_TRAINING';
        minutes = 55;
        intensity = 0.5;
      case DateTime.wednesday:
        type = 'RUNNING';
        minutes = 40;
        intensity = 0.78;
      case DateTime.friday:
        type = r.nextDouble() < 0.5 ? 'SOCCER' : null;
        minutes = 60;
        intensity = 0.68;
        hour = 20;
      default:
        type = r.nextDouble() < 0.4 ? 'WALKING' : null;
        minutes = 35;
        intensity = 0.35;
    }
    if (type != null && r.nextDouble() < 0.15) type = null;

    final g1 = _gauss(r);
    final g2 = _gauss(r);
    final g3 = _gauss(r);
    var sleep = 7.4 +
        (nextIsWeekend ? 0.6 : 0) -
        (screenBed ? 0.35 : 0) -
        (caffeineLate ? 0.3 : 0) -
        (workStress ? 0.25 : 0) +
        (readingBed ? 0.2 : 0) +
        g1 * 0.45;
    sleep = sleep.clamp(4.8, 9.3).toDouble();
    final bedShift = g2 * 25 +
        (screenBed ? 35 : 0) +
        (caffeineLate ? 20 : 0) -
        (readingBed ? 15 : 0) +
        (nextIsWeekend ? 50 : 0);
    final load = type == null ? 0.0 : minutes * intensity / 60.0;
    final z = g3 * 0.55 -
        (caffeineLate ? 0.55 : 0) -
        (lateMeal ? 0.45 : 0) -
        (screenBed ? 0.25 : 0) +
        (hydrated ? 0.2 : 0) -
        (workStress ? 0.35 : 0) +
        (readingBed ? 0.15 : 0) +
        (stretching ? 0.2 : 0) -
        (smoking ? 0.75 : 0) -
        0.35 * load +
        0.35 * (sleep - 7.6);

    return DayPlan._(
      caffeineLate: caffeineLate,
      lateMeal: lateMeal,
      screenBed: screenBed,
      hydrated: hydrated,
      workStress: workStress,
      readingBed: readingBed,
      stretching: stretching,
      smoking: smoking,
      workoutType: type,
      workoutMin: minutes,
      workoutHour: hour,
      workoutIntensity: intensity,
      sleepHours: sleep,
      bedShiftMin: bedShift,
      readinessNext: z,
    );
  }
}

/// Timing and stages of the night that starts on the evening of a day.
class NightPlan {
  final DateTime bed;
  final DateTime sleepStart;
  final DateTime wake;
  final List<SleepSegment> segments;

  const NightPlan(this.bed, this.sleepStart, this.wake, this.segments);

  static final Map<int, NightPlan> _cache = {};

  factory NightPlan.of(DateTime day) => _cache.putIfAbsent(_dayNo(day), () => NightPlan._build(day));

  SleepStage stageAt(DateTime t) {
    for (final s in segments) {
      if (!t.isBefore(s.start) && t.isBefore(s.end)) return s.stage;
    }
    return SleepStage.light;
  }

  factory NightPlan._build(DateTime day) {
    final p = DayPlan.of(day);
    final r = math.Random(_dayNo(day) * 101 + 3);
    final bed = DateTime(day.year, day.month, day.day, 23, 15).add(Duration(minutes: p.bedShiftMin.round()));
    final latency = 8 + r.nextInt(14);
    final sleepStart = bed.add(Duration(minutes: latency));
    final segs = <SleepSegment>[
      SleepSegment(bed, sleepStart, SleepStage.awake, DemoHealthSource.watchSource),
    ];
    var t = sleepStart;
    var asleep = 0.0;
    final target = p.sleepHours * 60;
    var cycle = 0;
    void add(SleepStage st, double minutes) {
      if (minutes <= 0.5) return;
      final e = t.add(Duration(seconds: (minutes * 60).round()));
      segs.add(SleepSegment(t, e, st, DemoHealthSource.watchSource));
      t = e;
      if (st != SleepStage.awake) asleep += minutes;
    }

    while (asleep < target) {
      final len = 90 + _gauss(r) * 8;
      final deep = len * (cycle == 0 ? 0.30 : cycle == 1 ? 0.22 : cycle == 2 ? 0.12 : 0.05);
      final rem = len * (cycle == 0 ? 0.10 : cycle == 1 ? 0.18 : cycle == 2 ? 0.25 : 0.32);
      final light = len - deep - rem;
      final remaining = target - asleep;
      final scale = remaining < len ? remaining / len : 1.0;
      add(SleepStage.light, light * 0.5 * scale);
      add(SleepStage.deep, deep * scale);
      add(SleepStage.light, light * 0.5 * scale);
      add(SleepStage.rem, rem * scale);
      if (r.nextDouble() < 0.5 && asleep < target) add(SleepStage.awake, 2.0 + r.nextInt(5));
      cycle++;
      if (cycle > 12) break;
    }
    return NightPlan(bed, sleepStart, t, segs);
  }
}
