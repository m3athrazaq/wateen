import 'dart:math' as math;

import '../models/raw.dart';
import '../models/settings.dart';

/// Cardiovascular load model.
///
/// Load is a Banister-style TRIMP computed on the fraction of heart-rate
/// reserve, with the first 10% of reserve treated as everyday baseline. Day
/// strain maps load onto a saturating 0..21 scale so that hard efforts get
/// progressively harder to raise further.
class StrainModel {
  /// Load (TRIMP) that raises strain by 63% of the remaining headroom.
  static const double tau = 98.0;

  /// Longest gap one heart-rate sample may stand for.
  static const Duration maxSampleSpan = Duration(minutes: 10);

  final double restHr;
  final double maxHr;
  final Sex sex;

  StrainModel({required this.restHr, required this.maxHr, required this.sex});

  static double strainFromLoad(double load) => load <= 0 ? 0 : 21.0 * (1 - math.exp(-load / tau));

  /// Load needed to reach [strain]; used to express targets.
  static double loadForStrain(double strain) {
    final s = strain.clamp(0.0, 20.9).toDouble();
    return -tau * math.log(1 - s / 21.0);
  }

  double get _a => sex == Sex.female ? 0.86 : 0.64;
  double get _b => sex == Sex.female ? 1.67 : 1.92;

  /// Fraction of heart-rate reserve used at [bpm].
  double reserveFraction(double bpm) =>
      ((bpm - restHr) / math.max(1.0, maxHr - restHr)).clamp(0.0, 1.15).toDouble();

  /// Load accumulated per minute at [bpm].
  double loadPerMinute(double bpm) {
    final x = reserveFraction(bpm) - 0.10;
    if (x <= 0) return 0;
    return x * _a * math.exp(_b * x);
  }

  /// Heart-rate zone 0..5 by percent of max HR (0 = under 50%).
  int zoneOf(double bpm) {
    final p = bpm / maxHr;
    if (p < 0.5) return 0;
    if (p < 0.6) return 1;
    if (p < 0.7) return 2;
    if (p < 0.8) return 3;
    if (p < 0.9) return 4;
    return 5;
  }

  /// Integrates load, zone minutes, average and peak heart rate over the
  /// samples that fall in [from, to). [samples] must be sorted by time.
  LoadResult accumulate(List<TimedValue> samples, DateTime from, DateTime to) {
    var load = 0.0;
    final zones = List<double>.filled(6, 0);
    var weighted = 0.0;
    var minutes = 0.0;
    double? peak;
    final start = lowerBound(samples, from);
    for (var i = start; i < samples.length; i++) {
      final s = samples[i];
      if (!s.time.isBefore(to)) break;
      final next = (i + 1 < samples.length && samples[i + 1].time.isBefore(to)) ? samples[i + 1].time : to;
      var span = next.difference(s.time);
      if (span > maxSampleSpan) span = maxSampleSpan;
      if (span.isNegative) continue;
      // A lone last sample stands for at most two minutes.
      if (next == to && span > const Duration(minutes: 2)) span = const Duration(minutes: 2);
      final m = span.inMilliseconds / 60000.0;
      if (m <= 0) continue;
      load += loadPerMinute(s.value) * m;
      zones[zoneOf(s.value)] += m;
      weighted += s.value * m;
      minutes += m;
      if (peak == null || s.value > peak) peak = s.value;
    }
    return LoadResult(
      load: load,
      zoneMinutes: zones,
      avgHr: minutes > 0 ? weighted / minutes : null,
      maxHr: peak,
      minutes: minutes,
    );
  }
}

class LoadResult {
  final double load;
  final List<double> zoneMinutes;
  final double? avgHr;
  final double? maxHr;
  final double minutes;
  const LoadResult({required this.load, required this.zoneMinutes, this.avgHr, this.maxHr, required this.minutes});
}

/// First index whose time is not before [t] (samples sorted by time).
int lowerBound(List<TimedValue> samples, DateTime t) {
  var lo = 0;
  var hi = samples.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (samples[mid].time.isBefore(t)) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Samples whose time falls in [from, to).
Iterable<TimedValue> samplesIn(List<TimedValue> samples, DateTime from, DateTime to) sync* {
  for (var i = lowerBound(samples, from); i < samples.length; i++) {
    final s = samples[i];
    if (!s.time.isBefore(to)) break;
    yield s;
  }
}
