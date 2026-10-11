import 'dart:math' as math;

double? meanOf(Iterable<double> xs) {
  var n = 0;
  var s = 0.0;
  for (final x in xs) {
    if (x.isNaN) continue;
    s += x;
    n++;
  }
  return n == 0 ? null : s / n;
}

/// Sample standard deviation (n - 1). Null when fewer than two values.
double? sdOf(Iterable<double> xs) {
  final list = xs.where((x) => !x.isNaN).toList();
  if (list.length < 2) return null;
  final m = list.reduce((a, b) => a + b) / list.length;
  var acc = 0.0;
  for (final x in list) {
    acc += (x - m) * (x - m);
  }
  return math.sqrt(acc / (list.length - 1));
}

/// Linear-interpolated percentile, [p] in 0..1.
double? percentileOf(Iterable<double> xs, double p) {
  final list = xs.where((x) => !x.isNaN).toList()..sort();
  if (list.isEmpty) return null;
  if (list.length == 1) return list.first;
  final pos = (list.length - 1) * p.clamp(0.0, 1.0);
  final lo = pos.floor();
  final hi = pos.ceil();
  if (lo == hi) return list[lo];
  return list[lo] + (list[hi] - list[lo]) * (pos - lo);
}

double? medianOf(Iterable<double> xs) => percentileOf(xs, 0.5);

double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Error function (Abramowitz & Stegun 7.1.26, |error| < 1.5e-7).
double erf(double x) {
  final sign = x < 0 ? -1.0 : 1.0;
  final ax = x.abs();
  const p = 0.3275911;
  const a1 = 0.254829592, a2 = -0.284496736, a3 = 1.421413741, a4 = -1.453152027, a5 = 1.061405429;
  final t = 1.0 / (1.0 + p * ax);
  final y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-ax * ax);
  return sign * y;
}

/// Standard normal cumulative distribution.
double normalCdf(double x) => 0.5 * (1.0 + erf(x / math.sqrt2));

/// Rolling statistics of one metric over a baseline window.
class Baseline {
  final double mean;
  final double sd;
  final int count;
  const Baseline(this.mean, this.sd, this.count);

  /// z-score with a floor on the deviation so tiny-variance baselines
  /// do not explode.
  double z(double value, double sdFloor) => (value - mean) / math.max(sd, sdFloor);

  Map<String, dynamic> toJson() => {'m': mean, 's': sd, 'n': count};

  static Baseline? fromValues(Iterable<double> values, {double defaultSd = 0}) {
    final list = values.where((v) => !v.isNaN).toList();
    if (list.isEmpty) return null;
    final m = list.reduce((a, b) => a + b) / list.length;
    final s = sdOf(list) ?? defaultSd;
    return Baseline(m, s, list.length);
  }
}
