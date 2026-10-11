import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wateen/data/demo_source.dart';
import 'package:wateen/engine/body_age.dart';
import 'package:wateen/engine/extract.dart';
import 'package:wateen/engine/insights.dart';
import 'package:wateen/engine/score.dart';
import 'package:wateen/engine/strain_model.dart';
import 'package:wateen/models/day.dart';
import 'package:wateen/models/metrics.dart';
import 'package:wateen/models/raw.dart';
import 'package:wateen/models/settings.dart';
import 'package:wateen/util/dates.dart';
import 'package:wateen/util/stats.dart';

List<TimedValue> steady(DateTime from, Duration length, double bpm, {Duration every = const Duration(minutes: 5)}) {
  final out = <TimedValue>[];
  for (var t = from; t.isBefore(from.add(length)); t = t.add(every)) {
    out.add(TimedValue(t, bpm));
  }
  return out;
}

void main() {
  group('stats', () {
    test('normal cdf', () {
      expect(normalCdf(0), closeTo(0.5, 1e-6));
      expect(normalCdf(1.96), closeTo(0.975, 1e-3));
      expect(normalCdf(-1.96), closeTo(0.025, 1e-3));
    });

    test('percentile and sd', () {
      expect(percentileOf([1, 2, 3, 4, 5], 0.5), 3);
      expect(sdOf([2, 4, 4, 4, 5, 5, 7, 9]), closeTo(2.138, 1e-3));
      expect(meanOf(const <double>[]), isNull);
    });

    test('bedtime minutes keep order across midnight', () {
      expect(bedtimeMinutes(DateTime(2026, 1, 1, 23, 30)), 330);
      expect(bedtimeMinutes(DateTime(2026, 1, 2, 0, 30)), 390);
      expect(bedtimeToClock(330), 23 * 60 + 30);
    });
  });

  group('strain', () {
    final model = StrainModel(restHr: 55, maxHr: 185, sex: Sex.male);

    test('mapping is monotonic, bounded and invertible', () {
      expect(StrainModel.strainFromLoad(0), 0);
      var prev = 0.0;
      for (var l = 10.0; l < 800; l += 10) {
        final s = StrainModel.strainFromLoad(l);
        expect(s, greaterThan(prev));
        expect(s, lessThan(21));
        prev = s;
      }
      expect(StrainModel.strainFromLoad(StrainModel.loadForStrain(12)), closeTo(12, 1e-9));
    });

    test('sedentary day lands in the light range', () {
      final start = DateTime(2026, 3, 1, 7);
      final hr = steady(start, const Duration(hours: 16), 72);
      final load = model.accumulate(hr, start, start.add(const Duration(hours: 16)));
      final s = StrainModel.strainFromLoad(load.load);
      expect(s, inInclusiveRange(1, 8));
      expect(load.minutes, closeTo(16 * 60, 3));
    });

    test('an hour of hard running is a strenuous day', () {
      final start = DateTime(2026, 3, 1, 7);
      final hr = [
        ...steady(start, const Duration(hours: 10), 75),
        ...steady(start.add(const Duration(hours: 10)), const Duration(minutes: 60), 160,
            every: const Duration(seconds: 5)),
        ...steady(start.add(const Duration(hours: 11)), const Duration(hours: 5), 75),
      ];
      final load = model.accumulate(hr, start, start.add(const Duration(hours: 16)));
      final s = StrainModel.strainFromLoad(load.load);
      expect(s, inInclusiveRange(12, 19));
      expect(load.zoneMinutes[4] + load.zoneMinutes[3], greaterThan(55));
    });
  });

  group('sleep', () {
    test('prefers the source with stages and sums stages', () {
      final bed = DateTime(2026, 3, 1, 23);
      final segs = <SleepSegment>[
        SleepSegment(bed, bed.add(const Duration(hours: 8)), SleepStage.inBed, 'phone'),
        SleepSegment(bed.add(const Duration(minutes: 10)), bed.add(const Duration(minutes: 100)), SleepStage.light, 'watch'),
        SleepSegment(bed.add(const Duration(minutes: 100)), bed.add(const Duration(minutes: 160)), SleepStage.deep, 'watch'),
        SleepSegment(bed.add(const Duration(minutes: 160)), bed.add(const Duration(minutes: 165)), SleepStage.awake, 'watch'),
        SleepSegment(bed.add(const Duration(minutes: 165)), bed.add(const Duration(minutes: 400)), SleepStage.light, 'watch'),
        SleepSegment(bed.add(const Duration(minutes: 400)), bed.add(const Duration(minutes: 460)), SleepStage.rem, 'watch'),
      ];
      final sessions = buildSessions(segs);
      expect(sessions, hasLength(1));
      final s = sessions.first;
      expect(s.source, 'watch');
      expect(s.summary.hasStages, isTrue);
      expect(s.summary.deepMin, closeTo(60, 0.01));
      expect(s.summary.remMin, closeTo(60, 0.01));
      expect(s.asleepMin, closeTo(90 + 60 + 235 + 60, 0.01));
      expect(s.summary.disturbances, 1);
      expect(s.summary.efficiency, greaterThan(0.9));
    });

    test('separate naps form their own sessions', () {
      final d = DateTime(2026, 3, 2);
      final segs = [
        SleepSegment(d.add(const Duration(hours: -1)), d.add(const Duration(hours: 6)), SleepStage.asleep, 'w'),
        SleepSegment(d.add(const Duration(hours: 14)), d.add(const Duration(hours: 15)), SleepStage.asleep, 'w'),
      ];
      expect(buildSessions(segs), hasLength(2));
    });
  });

  group('recovery', () {
    Contributor c(ContributorKind k, double effect, double w) => Contributor(kind: k, effect: effect, weight: w);

    test('neutral, good and poor nights', () {
      final neutral = Scorer.recoveryFromContributors([c(ContributorKind.hrv, 0, 0.5), c(ContributorKind.rhr, 0, 0.25)]);
      expect(neutral, inInclusiveRange(55, 65));
      final good = Scorer.recoveryFromContributors([c(ContributorKind.hrv, 1.5, 0.5), c(ContributorKind.rhr, 1, 0.25)]);
      expect(good, greaterThan(85));
      final poor = Scorer.recoveryFromContributors([c(ContributorKind.hrv, -1.8, 0.5), c(ContributorKind.rhr, -1.2, 0.25)]);
      expect(poor, lessThan(25));
      expect(zoneOf(poor), RecoveryZone.red);
      expect(zoneOf(good), RecoveryZone.green);
    });

    test('strain target follows recovery', () {
      final low = Scorer.strainTarget(15);
      final high = Scorer.strainTarget(90);
      expect(high.$1, greaterThan(low.$2));
      expect(high.$2, lessThanOrEqualTo(21));
    });

    test('sleep need adds strain and debt, subtracts naps', () {
      final need = Scorer.sleepNeedFor(base: 450, previousStrain: 17, shortfalls: [60, 30, 0], napMin: 20);
      expect(need.strainMin, closeTo((17 - 8) / 13 * 50, 1e-9));
      expect(need.debtMin, closeTo(0.5 * 60 + 0.25 * 30, 1e-9));
      expect(need.totalMin, closeTo(450 + need.strainMin + need.debtMin - 20, 1e-9));
    });
  });

  group('demo pipeline', () {
    late List<DayMetrics> metrics;
    late Map<String, DayInputs> inputs;
    final now = DateTime(2026, 9, 30, 21, 30);
    final settings = UserSettings(birthYear: 1991, dataMode: DataMode.demo);

    setUpAll(() async {
      final first = addDays(dayOf(now), -59);
      final raw = await DemoHealthSource().fetch(addDays(first, -1).add(const Duration(hours: 12)), now);
      final ex = Extractor(restHr: 50, maxHr: 185, sex: Sex.male, now: now);
      inputs = ex.extract(raw, first, dayOf(now));
      metrics = Scorer(settings).score(inputs.values.toList());
    });

    test('every day has a night and sane scores', () {
      expect(metrics, hasLength(60));
      final withSleep = metrics.where((m) => m.inputs.sleep != null).length;
      expect(withSleep, greaterThanOrEqualTo(58));
      for (final m in metrics) {
        expect(m.strain, inInclusiveRange(0, 21));
        if (m.sleepScore != null) expect(m.sleepScore!, inInclusiveRange(0, 100));
        if (m.recovery != null) expect(m.recovery!, inInclusiveRange(1, 99));
      }
    });

    test('recovery appears after calibration and varies', () {
      final scored = metrics.skip(6).where((m) => m.recovery != null).toList();
      expect(scored.length, greaterThan(45));
      final zones = scored.map((m) => m.zone).toSet();
      expect(zones, contains(RecoveryZone.green));
      expect(zones, contains(RecoveryZone.red));
      final hrvValues = metrics.where((m) => m.inputs.hrv != null).map((m) => m.inputs.hrv!).toList();
      expect(meanOf(hrvValues)!, inInclusiveRange(40, 65));
    });

    test('training days carry more strain', () {
      final withWorkout = metrics.where((m) => m.inputs.windowComplete && m.inputs.workouts.isNotEmpty);
      final without = metrics.where((m) => m.inputs.windowComplete && m.inputs.workouts.isEmpty);
      expect(meanOf(withWorkout.map((m) => m.strain))!, greaterThan(meanOf(without.map((m) => m.strain))! + 2));
    });

    test('journal insights recover the built-in effects', () {
      final journal = DemoHealthSource.journalFor(addDays(dayOf(now), -59), dayOf(now));
      final ins = journalInsights(journal, metrics);
      final caffeine = ins.firstWhere((i) => i.questionId == 'caffeine_late');
      expect(caffeine.enoughData, isTrue);
      expect(caffeine.effect!, lessThan(0));
    });

    test('body age is estimated', () {
      final r = estimateBodyAge(metrics, settings, now);
      expect(r, isNotNull);
      expect((r!.bodyAge - r.chronologicalAge).abs(), lessThanOrEqualTo(12));
    });

    test('inputs survive a JSON round trip', () {
      final d = inputs.values.firstWhere((i) => i.sleep != null && i.workouts.isNotEmpty);
      final back = DayInputs.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(d.toJson())) as Map));
      expect(back.key, d.key);
      expect(back.sleep!.asleepMin, closeTo(d.sleep!.asleepMin, 1e-9));
      expect(back.workouts.length, d.workouts.length);
      expect(back.hrSeries.length, d.hrSeries.length);
      expect(back.trimp, closeTo(d.trimp, 1e-9));
      expect(back.zoneMinutes.fold(0.0, (a, b) => a + b), closeTo(d.zoneMinutes.fold(0.0, (a, b) => a + b), 1e-6));
    });

    test('bedtime coach returns ordered options', () {
      final today = metrics.last;
      final need = SleepCoach.tonightNeed(settings, metrics, today);
      final opts = SleepCoach.options(settings, need, now);
      expect(opts, hasLength(3));
      expect(opts[0].bedtime.isBefore(opts[1].bedtime), isTrue);
      expect(opts[1].bedtime.isBefore(opts[2].bedtime), isTrue);
      expect(math.max(0, need.totalMin), greaterThan(300));
    });
  });
}
