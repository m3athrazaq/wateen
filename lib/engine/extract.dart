import 'dart:math' as math;

import '../models/day.dart';
import '../models/raw.dart';
import '../models/settings.dart';
import '../util/dates.dart';
import '../util/stats.dart';
import 'strain_model.dart';

/// A merged sleep period built from one source's segments.
class SleepSession {
  final SleepSummary summary;
  final String source;
  const SleepSession(this.summary, this.source);

  DateTime get start => summary.start;
  DateTime get end => summary.end;
  double get asleepMin => summary.asleepMin;
}

/// Turns raw samples into per-day inputs.
class Extractor {
  /// Sleep sessions shorter than this (asleep) can only be naps.
  static const double mainSleepMinMinutes = 120;
  static const Duration clusterGap = Duration(minutes: 90);

  final double restHr;
  final double maxHr;
  final Sex sex;
  final DateTime now;
  final StrainModel model;

  Extractor({required this.restHr, required this.maxHr, required this.sex, required this.now})
      : model = StrainModel(restHr: restHr, maxHr: maxHr, sex: sex);

  /// Builds inputs for every calendar day from [firstDay] to [lastDay].
  Map<String, DayInputs> extract(RawBundle raw, DateTime firstDay, DateTime lastDay) {
    raw.sortAll();
    final sessions = buildSessions(raw.sleep);
    final byEndDay = <String, List<SleepSession>>{};
    for (final s in sessions) {
      byEndDay.putIfAbsent(dayKey(s.end), () => []).add(s);
    }

    SleepSession? mainFor(DateTime day) {
      final list = byEndDay[dayKey(day)];
      if (list == null) return null;
      SleepSession? best;
      for (final s in list) {
        if (s.asleepMin < mainSleepMinMinutes) continue;
        if (best == null || s.asleepMin > best.asleepMin) best = s;
      }
      return best;
    }

    final out = <String, DayInputs>{};
    for (var d = dayOf(firstDay); !d.isAfter(dayOf(lastDay)); d = addDays(d, 1)) {
      final main = mainFor(d);
      final next = mainFor(addDays(d, 1));
      final naps = <NapSummary>[];
      for (final s in byEndDay[dayKey(d)] ?? const <SleepSession>[]) {
        if (identical(s, main) || s.asleepMin < 10) continue;
        naps.add(NapSummary(s.start, s.end, s.asleepMin));
      }
      out[dayKey(d)] = _buildDay(raw, d, main, next, naps);
    }
    return out;
  }

  DayInputs _buildDay(RawBundle raw, DateTime d, SleepSession? main, SleepSession? next, List<NapSummary> naps) {
    final windowStart = main?.end ?? DateTime(d.year, d.month, d.day, 4);
    var windowEnd = next?.start ?? DateTime(d.year, d.month, d.day + 1, 4);
    if (!windowEnd.isAfter(windowStart)) windowEnd = windowStart.add(const Duration(hours: 16));
    var complete = true;
    if (windowEnd.isAfter(now)) {
      windowEnd = now.isAfter(windowStart) ? now : windowStart;
      complete = false;
    }

    // --- Night metrics (the main sleep that ended this day).
    double? hrv;
    double? rhr;
    var rhrFromSleep = false;
    double? rr;
    double? spo2;
    double? temp;
    if (main != null) {
      final s = main.start;
      final e = main.end;
      hrv = meanOf(samplesIn(raw.hrv, s, e).map((v) => v.value));
      hrv ??= meanOf(samplesIn(raw.hrv, e, e.add(const Duration(hours: 3))).map((v) => v.value));
      final sleepHr = samplesIn(raw.heartRate, s, e).map((v) => v.value).toList()..sort();
      if (sleepHr.length >= 6) {
        final take = math.max(3, (sleepHr.length * 0.25).round());
        rhr = meanOf(sleepHr.take(take));
        rhrFromSleep = true;
      }
      rr = meanOf(samplesIn(raw.respiratory, s, e).map((v) => v.value));
      spo2 = meanOf(samplesIn(raw.spo2, s, e).map((v) => normalizeSpo2(v.value)));
      temp = meanOf(samplesIn(raw.temperature, s.subtract(const Duration(hours: 2)), e.add(const Duration(hours: 6)))
          .map((v) => v.value));
    }
    if (rhr == null) {
      final dayRhr = samplesIn(raw.restingHr, d, addDays(d, 1)).map((v) => v.value).toList();
      if (dayRhr.isNotEmpty) rhr = dayRhr.last;
    }
    if (hrv == null && main == null) {
      // Without a recorded night use the earliest reading of the day.
      final early = samplesIn(raw.hrv, d, DateTime(d.year, d.month, d.day, 11)).toList();
      if (early.isNotEmpty) hrv = early.first.value;
    }

    // --- Day load.
    final load = model.accumulate(raw.heartRate, windowStart, windowEnd);

    // --- Workouts.
    final workouts = <WorkoutSummary>[];
    final wFrom = windowStart.subtract(const Duration(minutes: 30));
    for (final w in raw.workouts) {
      if (w.start.isBefore(wFrom) || !w.start.isBefore(windowEnd)) continue;
      final wl = model.accumulate(raw.heartRate, w.start, w.end);
      workouts.add(WorkoutSummary(
        start: w.start,
        end: w.end,
        type: w.type,
        kcal: w.kcal,
        distanceM: w.distanceM,
        trimp: wl.load,
        avgHr: wl.avgHr,
        maxHr: wl.maxHr,
      ));
    }

    final stress = _stress(raw, windowStart, windowEnd, workouts);
    final series = _series(raw.heartRate, windowStart, windowEnd);

    return DayInputs(
      date: d,
      sleep: main?.summary,
      naps: naps,
      hrv: hrv,
      hrvIsRmssd: raw.hrvIsRmssd,
      rhr: rhr,
      rhrFromSleep: rhrFromSleep,
      respiratory: rr,
      spo2: spo2,
      temperature: temp,
      steps: raw.stepsByDay[dayKey(d)],
      activeKcal: raw.activeKcalByDay[dayKey(d)],
      trimp: load.load,
      zoneMinutes: load.zoneMinutes,
      avgHr: load.avgHr,
      maxHr: load.maxHr,
      windowStart: windowStart,
      windowEnd: windowEnd,
      windowComplete: complete,
      workouts: workouts,
      stress: stress,
      hrSeries: series,
    );
  }

  /// Five-minute average heart rate across the day window.
  List<HrPoint> _series(List<TimedValue> hr, DateTime from, DateTime to) {
    const bucket = Duration(minutes: 5);
    final sums = <int, double>{};
    final counts = <int, int>{};
    for (final s in samplesIn(hr, from, to)) {
      final idx = s.time.difference(from).inMilliseconds ~/ bucket.inMilliseconds;
      sums[idx] = (sums[idx] ?? 0.0) + s.value;
      counts[idx] = (counts[idx] ?? 0) + 1;
    }
    final keys = sums.keys.toList()..sort();
    return [
      for (final k in keys) HrPoint(from.add(bucket * k + bucket ~/ 2), sums[k]! / counts[k]!),
    ];
  }

  /// Stress on a 0..3 scale from heart rate while not exercising or moving.
  StressSummary? _stress(RawBundle raw, DateTime from, DateTime to, List<WorkoutSummary> workouts) {
    if (!to.isAfter(from)) return null;
    final reserve = math.max(30.0, maxHr - restHr);
    final ref = restHr + 10;
    final scale = 0.30 * reserve;
    const bucket = Duration(minutes: 30);
    final nBuckets = math.max(1, (to.difference(from).inMinutes / 30).ceil());
    final bSum = List<double>.filled(nBuckets, 0);
    final bMin = List<double>.filled(nBuckets, 0);
    var low = 0.0, med = 0.0, high = 0.0, weighted = 0.0, minutes = 0.0;

    bool inWorkout(DateTime t) {
      for (final w in workouts) {
        if (!t.isBefore(w.start.subtract(const Duration(minutes: 5))) &&
            t.isBefore(w.end.add(const Duration(minutes: 10)))) {
          return true;
        }
      }
      return false;
    }

    // Step samples are sorted by start; heart-rate samples are visited in time
    // order, so a forward-only pointer keeps this linear.
    final steps = raw.stepSamples;
    var j = 0;
    bool moving(DateTime t) {
      final a = t.subtract(const Duration(minutes: 5));
      final b = t.add(const Duration(minutes: 1));
      final floor = a.subtract(const Duration(hours: 1));
      while (j < steps.length && steps[j].start.isBefore(floor)) {
        j++;
      }
      for (var k = j; k < steps.length; k++) {
        final s = steps[k];
        if (s.start.isAfter(b)) break;
        if (s.end.isBefore(a)) continue;
        final mins = math.max(1.0, s.end.difference(s.start).inSeconds / 60.0);
        if (s.count / mins > 20) return true;
      }
      return false;
    }

    final hr = raw.heartRate;
    for (var i = lowerBound(hr, from); i < hr.length; i++) {
      final s = hr[i];
      if (!s.time.isBefore(to)) break;
      final next = (i + 1 < hr.length && hr[i + 1].time.isBefore(to)) ? hr[i + 1].time : to;
      var span = next.difference(s.time);
      if (span > StrainModel.maxSampleSpan) span = StrainModel.maxSampleSpan;
      final m = span.inMilliseconds / 60000.0;
      if (m <= 0) continue;
      if (model.reserveFraction(s.value) > 0.55) continue;
      if (inWorkout(s.time) || moving(s.time)) continue;
      final level = clampD(3 * (s.value - ref) / scale, 0, 3);
      weighted += level * m;
      minutes += m;
      if (level < 1) {
        low += m;
      } else if (level < 2) {
        med += m;
      } else {
        high += m;
      }
      final bi = (s.time.difference(from).inMilliseconds ~/ bucket.inMilliseconds).clamp(0, nBuckets - 1).toInt();
      bSum[bi] += level * m;
      bMin[bi] += m;
    }
    if (minutes < 1) return null;
    return StressSummary(
      score: minutes >= 60 ? weighted / minutes : null,
      lowMin: low,
      medMin: med,
      highMin: high,
      buckets: [for (var i = 0; i < nBuckets; i++) bMin[i] > 0 ? bSum[i] / bMin[i] : null],
      bucketStart: from,
    );
  }
}

/// Apple Health reports oxygen saturation as a 0..1 fraction; Health Connect as a percentage.
double normalizeSpo2(double v) => v <= 1.5 ? v * 100 : v;

/// Groups raw sleep segments into sessions, choosing one source per session.
List<SleepSession> buildSessions(List<SleepSegment> segments) {
  final valid = segments
      .where((s) => s.end.isAfter(s.start) && s.end.difference(s.start) < const Duration(hours: 18))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final clusters = <List<SleepSegment>>[];
  DateTime? clusterEnd;
  for (final s in valid) {
    if (clusters.isEmpty || clusterEnd == null || s.start.isAfter(clusterEnd.add(Extractor.clusterGap))) {
      clusters.add([s]);
      clusterEnd = s.end;
    } else {
      clusters.last.add(s);
      if (s.end.isAfter(clusterEnd)) clusterEnd = s.end;
    }
  }

  final out = <SleepSession>[];
  for (final c in clusters) {
    final bySource = <String, List<SleepSegment>>{};
    for (final s in c) {
      bySource.putIfAbsent(s.source, () => []).add(s);
    }
    String? bestSource;
    var bestScore = -1.0;
    bySource.forEach((src, list) {
      var score = 0.0;
      for (final s in list) {
        if (s.isDetailedStage) {
          score += s.minutes * 10;
        } else if (s.stage == SleepStage.asleep || s.stage == SleepStage.session) {
          score += s.minutes * 2;
        } else {
          score += s.minutes * 0.5;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestSource = src;
      }
    });
    if (bestSource == null) continue;
    final summary = summarizeSleep(bySource[bestSource]!);
    if (summary != null) out.add(SleepSession(summary, bestSource!));
  }
  return out;
}

/// Summarises the segments of one source for one sleep period.
SleepSummary? summarizeSleep(List<SleepSegment> segs) {
  if (segs.isEmpty) return null;
  segs.sort((a, b) => a.start.compareTo(b.start));
  var start = segs.first.start;
  var end = segs.first.end;
  for (final s in segs) {
    if (s.start.isBefore(start)) start = s.start;
    if (s.end.isAfter(end)) end = s.end;
  }
  var light = 0.0, deep = 0.0, rem = 0.0, unspecified = 0.0, awake = 0.0, inBed = 0.0, session = 0.0;
  for (final s in segs) {
    switch (s.stage) {
      case SleepStage.light:
        light += s.minutes;
      case SleepStage.deep:
        deep += s.minutes;
      case SleepStage.rem:
        rem += s.minutes;
      case SleepStage.asleep:
        unspecified += s.minutes;
      case SleepStage.awake:
      case SleepStage.outOfBed:
        awake += s.minutes;
      case SleepStage.inBed:
        inBed += s.minutes;
      case SleepStage.session:
        session += s.minutes;
    }
  }
  final hasStages = light + deep + rem > 0;
  final span = end.difference(start).inSeconds / 60.0;
  var asleep = light + deep + rem + unspecified;
  if (asleep <= 0 && session > 0) asleep = math.max(0.0, session - awake);
  if (asleep <= 0 && inBed > 0) asleep = inBed * 0.92;
  if (asleep <= 0) return null;
  asleep = math.min(asleep, span);

  final staged = segs
      .where((s) => s.stage != SleepStage.inBed && s.stage != SleepStage.session)
      .map((s) => StageSpan(s.start, s.end, s.stage))
      .toList();
  if (staged.isEmpty) {
    staged.add(StageSpan(start, end, SleepStage.asleep));
  }

  // Awakenings between the first and last asleep segment.
  DateTime? firstAsleep;
  DateTime? lastAsleep;
  for (final s in segs) {
    if (!s.isAsleep) continue;
    if (firstAsleep == null || s.start.isBefore(firstAsleep)) firstAsleep = s.start;
    if (lastAsleep == null || s.end.isAfter(lastAsleep)) lastAsleep = s.end;
  }
  var disturbances = 0;
  if (firstAsleep != null && lastAsleep != null) {
    for (final s in segs) {
      if (s.stage != SleepStage.awake) continue;
      if (s.start.isAfter(firstAsleep) && s.end.isBefore(lastAsleep) && s.minutes >= 1) disturbances++;
    }
  }

  return SleepSummary(
    start: start,
    end: end,
    asleepMin: asleep,
    inBedMin: span,
    awakeMin: math.max(awake, span - asleep),
    lightMin: light,
    deepMin: deep,
    remMin: rem,
    hasStages: hasStages,
    disturbances: disturbances,
    spans: staged,
  );
}
