import '../util/stats.dart';
import 'day.dart';

enum RecoveryZone { red, yellow, green }

RecoveryZone zoneOf(int recovery) =>
    recovery >= 67 ? RecoveryZone.green : (recovery >= 34 ? RecoveryZone.yellow : RecoveryZone.red);

enum ContributorKind { hrv, rhr, respiratory, sleep, temperature }

/// One input to the recovery score and how it compares with the personal baseline.
class Contributor {
  final ContributorKind kind;
  final double? value;
  final double? baseline;

  /// Signed effect on recovery in standard deviations; positive helps.
  final double effect;
  final double weight;

  const Contributor({required this.kind, this.value, this.baseline, required this.effect, required this.weight});
}

/// How tonight's (or last night's) sleep need was built up.
class SleepNeed {
  final double baseMin;
  final double strainMin;
  final double debtMin;
  final double napMin;

  const SleepNeed({required this.baseMin, required this.strainMin, required this.debtMin, required this.napMin});

  double get totalMin => clampD(baseMin + strainMin + debtMin - napMin, baseMin * 0.75, baseMin + 150);

  /// Need without carried-over debt; shortfalls are measured against this so
  /// debt does not feed on itself.
  double get nightlyMin => clampD(baseMin + strainMin - napMin, baseMin * 0.75, baseMin + 150);
}

class DayMetrics {
  final DayInputs inputs;
  final Baseline? hrvBase;
  final Baseline? rhrBase;
  final Baseline? rrBase;
  final Baseline? tempBase;
  final Baseline? spo2Base;

  /// Need for the main sleep that ended on this day.
  final SleepNeed? sleepNeed;

  /// Hours slept vs need, 0..1.
  final double? sleepPerformance;

  /// Composite sleep score 0..100.
  final double? sleepScore;

  /// Bed/wake time consistency 0..1 versus the previous nights.
  final double? consistency;

  /// Unpaid sleep minutes left after this night.
  final double debtAfterMin;

  final int? recovery;
  final bool calibrating;
  final List<Contributor> contributors;

  /// Day strain on the 0..21 scale.
  final double strain;
  final double targetLo;
  final double targetHi;

  const DayMetrics({
    required this.inputs,
    this.hrvBase,
    this.rhrBase,
    this.rrBase,
    this.tempBase,
    this.spo2Base,
    this.sleepNeed,
    this.sleepPerformance,
    this.sleepScore,
    this.consistency,
    this.debtAfterMin = 0,
    this.recovery,
    this.calibrating = false,
    this.contributors = const [],
    required this.strain,
    required this.targetLo,
    required this.targetHi,
  });

  DateTime get date => inputs.date;

  RecoveryZone? get zone => recovery == null ? null : zoneOf(recovery!);
}
