import '../models/metrics.dart';
import '../models/settings.dart';
import '../util/stats.dart';

enum AgeFactor { sleepHours, consistency, moderateMinutes, vigorousMinutes, steps, restingHr, strength }

class AgeContribution {
  final AgeFactor factor;
  final double value;

  /// Years added (positive) or removed (negative).
  final double years;
  const AgeContribution(this.factor, this.value, this.years);
}

class BodyAgeResult {
  final int chronologicalAge;
  final double bodyAge;
  final List<AgeContribution> contributions;
  final int daysUsed;
  const BodyAgeResult(this.chronologicalAge, this.bodyAge, this.contributions, this.daysUsed);
}

/// A lifestyle-based age estimate from the last 30 days. Thresholds follow
/// widely used guidance (7–9 h sleep, 150 min moderate / 75 min vigorous
/// activity a week, daily steps, resting heart rate). It is an estimate for
/// motivation, not a medical measurement.
BodyAgeResult? estimateBodyAge(List<DayMetrics> metrics, UserSettings settings, DateTime now) {
  final recent = metrics.where((m) => now.difference(m.date).inDays <= 30 && m.inputs.hasAnyData).toList();
  if (recent.length < 14) return null;
  final weeks = recent.length / 7.0;
  final out = <AgeContribution>[];

  final sleepH = meanOf(recent.where((m) => m.inputs.sleep != null).map((m) => m.inputs.sleep!.asleepMin / 60));
  if (sleepH != null) {
    double y;
    if (sleepH < 6) {
      y = 2.5;
    } else if (sleepH < 7) {
      y = 1.0;
    } else if (sleepH <= 8.5) {
      y = -0.5;
    } else if (sleepH <= 9.5) {
      y = 0.3;
    } else {
      y = 1.0;
    }
    out.add(AgeContribution(AgeFactor.sleepHours, sleepH, y));
  }

  final cons = meanOf(recent.where((m) => m.consistency != null).map((m) => m.consistency!));
  if (cons != null) {
    final y = cons >= 0.8 ? -0.5 : (cons >= 0.6 ? 0.0 : 1.0);
    out.add(AgeContribution(AgeFactor.consistency, cons * 100, y));
  }

  double zoneSum(int from, int to) {
    var s = 0.0;
    for (final m in recent) {
      for (var z = from; z <= to; z++) {
        s += m.inputs.zoneMinutes[z];
      }
    }
    return s;
  }

  final moderate = zoneSum(2, 3) / weeks;
  out.add(AgeContribution(AgeFactor.moderateMinutes, moderate, moderate >= 150 ? -1.5 : (moderate >= 75 ? -0.5 : 1.5)));
  final vigorous = zoneSum(4, 5) / weeks;
  out.add(AgeContribution(AgeFactor.vigorousMinutes, vigorous, vigorous >= 75 ? -1.0 : (vigorous >= 30 ? -0.3 : 0.5)));

  final steps = meanOf(recent.where((m) => (m.inputs.steps ?? 0) > 0).map((m) => m.inputs.steps!.toDouble()));
  if (steps != null) {
    double y;
    if (steps >= 10000) {
      y = -1.5;
    } else if (steps >= 7500) {
      y = -0.8;
    } else if (steps >= 5000) {
      y = 0.0;
    } else {
      y = 1.5;
    }
    out.add(AgeContribution(AgeFactor.steps, steps, y));
  }

  final rhr = meanOf(recent.where((m) => m.inputs.rhr != null).map((m) => m.inputs.rhr!));
  if (rhr != null) {
    double y;
    if (rhr < 55) {
      y = -1.0;
    } else if (rhr < 65) {
      y = 0.0;
    } else if (rhr < 75) {
      y = 1.0;
    } else {
      y = 2.0;
    }
    out.add(AgeContribution(AgeFactor.restingHr, rhr, y));
  }

  var strengthSessions = 0;
  for (final m in recent) {
    for (final w in m.inputs.workouts) {
      if (isStrengthWorkout(w.type)) strengthSessions++;
    }
  }
  final perWeek = strengthSessions / weeks;
  out.add(AgeContribution(AgeFactor.strength, perWeek, perWeek >= 2 ? -1.0 : (perWeek >= 1 ? -0.3 : 0.5)));

  final age = settings.ageAt(now);
  final delta = clampD(out.fold(0.0, (a, c) => a + c.years), -12, 12);
  return BodyAgeResult(age, age + delta, out, recent.length);
}

bool isStrengthWorkout(String type) {
  final t = type.toUpperCase();
  return t.contains('STRENGTH') ||
      t.contains('WEIGHT') ||
      t.contains('CALISTHENICS') ||
      t.contains('CORE_TRAINING') ||
      t.contains('CROSS_TRAINING') ||
      t.contains('HIGH_INTENSITY');
}
