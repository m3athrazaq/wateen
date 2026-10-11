import 'dart:math' as math;

import '../models/day.dart';
import '../models/metrics.dart';
import '../models/settings.dart';
import '../util/dates.dart';
import '../util/stats.dart';
import 'strain_model.dart';

/// Turns per-day inputs into scores, walking forward in time so each day only
/// sees its own past (personal baselines, sleep debt).
class Scorer {
  static const int baselineDays = 30;
  static const int minBaselineDays = 4;

  final UserSettings settings;
  Scorer(this.settings);

  List<DayMetrics> score(List<DayInputs> days) {
    final sorted = List<DayInputs>.from(days)..sort((a, b) => a.date.compareTo(b.date));
    final out = <DayMetrics>[];
    final byKey = <String, DayMetrics>{};
    final shortfall = <String, double>{};

    for (var i = 0; i < sorted.length; i++) {
      final cur = sorted[i];
      final d = cur.date;
      final history = <DayInputs>[];
      for (var j = i - 1; j >= 0; j--) {
        final gap = daysBetween(sorted[j].date, d);
        if (gap > baselineDays) break;
        if (gap >= 1) history.add(sorted[j]);
      }

      final hrvBase = Baseline.fromValues(history
          .where((h) => h.hrv != null && h.hrv! > 0 && h.hrvIsRmssd == cur.hrvIsRmssd)
          .map((h) => math.log(h.hrv!)));
      final rhrKindFromSleep = cur.rhr != null ? cur.rhrFromSleep : _mostlyFromSleep(history);
      final rhrBase = Baseline.fromValues(
          history.where((h) => h.rhr != null && h.rhrFromSleep == rhrKindFromSleep).map((h) => h.rhr!));
      final rrBase = Baseline.fromValues(history.where((h) => h.respiratory != null).map((h) => h.respiratory!));
      final tempBase = Baseline.fromValues(history.where((h) => h.temperature != null).map((h) => h.temperature!));
      final spo2Base = Baseline.fromValues(history.where((h) => h.spo2 != null).map((h) => h.spo2!));

      // ---- Sleep need for the night that ended on this day.
      final prev = byKey[dayKey(addDays(d, -1))];
      final need = sleepNeedFor(
        base: settings.sleepNeedBaseMin.toDouble(),
        previousStrain: prev?.strain,
        shortfalls: [
          shortfall[dayKey(addDays(d, -1))] ?? 0.0,
          shortfall[dayKey(addDays(d, -2))] ?? 0.0,
          shortfall[dayKey(addDays(d, -3))] ?? 0.0,
        ],
        napMin: prev?.inputs.napMinutes ?? 0.0,
      );

      double? perf;
      double? sleepScore;
      double? consistency;
      final sleep = cur.sleep;
      if (sleep != null) {
        perf = math.min(1.0, sleep.asleepMin / need.totalMin);
        consistency = _consistency(sleep.start, sleep.end, history);
        sleepScore = sleepScoreOf(
          performance: perf,
          efficiency: sleep.efficiency,
          consistency: consistency,
          restorativeRatio: sleep.hasStages && sleep.asleepMin > 0 ? sleep.restorativeMin / sleep.asleepMin : null,
        );
        shortfall[cur.key] = math.max(0.0, need.nightlyMin - sleep.asleepMin);
      }

      final strain = StrainModel.strainFromLoad(cur.trimp);

      // ---- Recovery.
      final contributors = <Contributor>[];
      if (cur.hrv != null && cur.hrv! > 0 && hrvBase != null && hrvBase.count >= minBaselineDays) {
        contributors.add(Contributor(
          kind: ContributorKind.hrv,
          value: cur.hrv,
          baseline: math.exp(hrvBase.mean),
          effect: clampD(hrvBase.z(math.log(cur.hrv!), 0.07), -3, 3),
          weight: 0.50,
        ));
      }
      if (cur.rhr != null && rhrBase != null && rhrBase.count >= minBaselineDays) {
        contributors.add(Contributor(
          kind: ContributorKind.rhr,
          value: cur.rhr,
          baseline: rhrBase.mean,
          effect: clampD(-rhrBase.z(cur.rhr!, 1.5), -3, 3),
          weight: 0.25,
        ));
      }
      final hasCore = contributors.isNotEmpty;
      if (hasCore && sleepScore != null) {
        contributors.add(Contributor(
          kind: ContributorKind.sleep,
          value: sleepScore,
          baseline: 85,
          effect: clampD((sleepScore / 100 - 0.85) / 0.15, -2.5, 1.0),
          weight: 0.15,
        ));
      }
      if (hasCore && cur.respiratory != null && rrBase != null && rrBase.count >= minBaselineDays) {
        final dev = (cur.respiratory! - rrBase.mean).abs() / math.max(rrBase.sd, 0.35);
        contributors.add(Contributor(
          kind: ContributorKind.respiratory,
          value: cur.respiratory,
          baseline: rrBase.mean,
          effect: clampD(-math.max(0.0, dev - 0.5), -3, 0),
          weight: 0.05,
        ));
      }
      if (hasCore && cur.temperature != null && tempBase != null && tempBase.count >= minBaselineDays) {
        final dev = (cur.temperature! - tempBase.mean).abs() / math.max(tempBase.sd, 0.15);
        contributors.add(Contributor(
          kind: ContributorKind.temperature,
          value: cur.temperature,
          baseline: tempBase.mean,
          effect: clampD(-math.max(0.0, dev - 0.5), -3, 0),
          weight: 0.05,
        ));
      }

      int? recovery;
      if (hasCore) recovery = recoveryFromContributors(contributors);
      final calibrating = recovery == null && (cur.hrv != null || cur.rhr != null);
      final target = strainTarget(recovery);

      final m = DayMetrics(
        inputs: cur,
        hrvBase: hrvBase,
        rhrBase: rhrBase,
        rrBase: rrBase,
        tempBase: tempBase,
        spo2Base: spo2Base,
        sleepNeed: need,
        sleepPerformance: perf,
        sleepScore: sleepScore,
        consistency: consistency,
        debtAfterMin: _debt([
          shortfall[cur.key] ?? 0.0,
          shortfall[dayKey(addDays(d, -1))] ?? 0.0,
          shortfall[dayKey(addDays(d, -2))] ?? 0.0,
        ]),
        recovery: recovery,
        calibrating: calibrating,
        contributors: contributors,
        strain: strain,
        targetLo: target.$1,
        targetHi: target.$2,
      );
      out.add(m);
      byKey[cur.key] = m;
    }
    return out;
  }

  static bool _mostlyFromSleep(List<DayInputs> history) {
    var sleepKind = 0, other = 0;
    for (final h in history) {
      if (h.rhr == null) continue;
      if (h.rhrFromSleep) {
        sleepKind++;
      } else {
        other++;
      }
    }
    return sleepKind >= other;
  }

  /// Weighted carry-over of the last three nights' shortfalls.
  static double _debt(List<double> shortfalls) {
    const w = [0.5, 0.25, 0.15];
    var s = 0.0;
    for (var i = 0; i < shortfalls.length && i < w.length; i++) {
      s += w[i] * shortfalls[i];
    }
    return math.min(s, 120.0);
  }

  static SleepNeed sleepNeedFor({
    required double base,
    double? previousStrain,
    required List<double> shortfalls,
    double napMin = 0,
  }) {
    final strainMin = (previousStrain != null && previousStrain > 8) ? (previousStrain - 8) / 13 * 50 : 0.0;
    return SleepNeed(baseMin: base, strainMin: strainMin, debtMin: _debt(shortfalls), napMin: napMin);
  }

  /// Bed and wake time regularity versus up to four previous nights.
  static double? _consistency(DateTime bed, DateTime wake, List<DayInputs> history) {
    final prior = history.where((h) => h.sleep != null).take(4).toList();
    if (prior.length < 2) return null;
    final mb = meanOf(prior.map((h) => bedtimeMinutes(h.sleep!.start)))!;
    final mw = meanOf(prior.map((h) => minuteOfDay(h.sleep!.end).toDouble()))!;
    final dev = ((bedtimeMinutes(bed) - mb).abs() + (minuteOfDay(wake) - mw).abs()) / 2;
    return clampD(1 - dev / 120, 0, 1);
  }

  static double sleepScoreOf({
    required double performance,
    required double efficiency,
    double? consistency,
    double? restorativeRatio,
  }) {
    final eff = clampD((efficiency - 0.70) / 0.25, 0, 1);
    final cons = consistency ?? 0.8;
    final rest = restorativeRatio == null ? 0.8 : clampD(restorativeRatio / 0.40, 0, 1);
    return 100 * (0.70 * performance + 0.10 * eff + 0.10 * cons + 0.10 * rest);
  }

  static int recoveryFromContributors(List<Contributor> cs) {
    var wSum = 0.0, acc = 0.0;
    for (final c in cs) {
      wSum += c.weight;
      acc += c.weight * c.effect;
    }
    final composite = wSum == 0 ? 0.0 : acc / wSum;
    final r = (100 * normalCdf(0.85 * composite + 0.25)).round();
    return r < 1 ? 1 : (r > 99 ? 99 : r);
  }

  /// Suggested day strain range for a given recovery.
  static (double, double) strainTarget(int? recovery) {
    if (recovery == null) return (8.0, 12.0);
    final center = 6 + recovery * 0.12;
    return (math.max(4.0, center - 1.5), math.min(20.5, center + 1.5));
  }
}

/// Bedtime suggestions for the coming night.
class BedtimeOption {
  final double fraction;
  final DateTime bedtime;
  final double sleepMinutes;
  const BedtimeOption(this.fraction, this.bedtime, this.sleepMinutes);
}

class SleepCoach {
  /// Need for tonight given today's strain so far, recent shortfalls and naps.
  static SleepNeed tonightNeed(UserSettings s, List<DayMetrics> metrics, DayMetrics today) {
    double shortfallOf(DayMetrics? m) {
      if (m == null || m.inputs.sleep == null || m.sleepNeed == null) return 0;
      return math.max(0.0, m.sleepNeed!.nightlyMin - m.inputs.sleep!.asleepMin);
    }

    DayMetrics? at(int back) {
      final key = dayKey(addDays(today.date, -back));
      for (final m in metrics) {
        if (m.inputs.key == key) return m;
      }
      return null;
    }

    return Scorer.sleepNeedFor(
      base: s.sleepNeedBaseMin.toDouble(),
      previousStrain: today.strain,
      shortfalls: [shortfallOf(today), shortfallOf(at(1)), shortfallOf(at(2))],
      napMin: today.inputs.napMinutes,
    );
  }

  static List<BedtimeOption> options(UserSettings s, SleepNeed need, DateTime now, {double efficiency = 0.9}) {
    var wake = DateTime(now.year, now.month, now.day, s.wakeTimeMin ~/ 60, s.wakeTimeMin % 60);
    if (!wake.isAfter(now.add(const Duration(hours: 3)))) {
      wake = DateTime(now.year, now.month, now.day + 1, s.wakeTimeMin ~/ 60, s.wakeTimeMin % 60);
    }
    final eff = clampD(efficiency, 0.75, 0.98);
    return [
      for (final f in const [1.0, 0.85, 0.70])
        BedtimeOption(
          f,
          wake.subtract(Duration(minutes: (need.totalMin * f / eff + 15).round())),
          need.totalMin * f,
        ),
    ];
  }
}
