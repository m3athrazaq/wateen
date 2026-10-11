import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wateen/data/import_format.dart';
import 'package:wateen/engine/extract.dart';
import 'package:wateen/engine/insights.dart';
import 'package:wateen/engine/score.dart';
import 'package:wateen/models/settings.dart';
import 'package:wateen/util/dates.dart';
import 'package:wateen/util/stats.dart';

const _tiny = '''
{"format":"wateen-raw","version":1,"hrvType":"rmssd",
 "heartRate":[[1790000000,60],[1790000300,62]],
 "hrv":[[1790000100,55.5]],
 "sleep":[[1789980000,1790001000,"core","Watch"],[1790001000,1790002000,"deep","Watch"]],
 "workouts":[{"start":1790010000,"end":1790012000,"type":"RUNNING","kcal":300,"distance":5000}],
 "steps":[[1790010000,1790010600,900]],
 "dailySteps":{"2026-09-21":9000,"bad-key":5},
 "journal":{"2026-09-21":{"caffeine_late":true,"hydrated":false,"x":"no"}}}
''';

void main() {
  test('parses the compact rows', () {
    final d = ImportedData.parse(_tiny, now: DateTime(2030));
    expect(d.shiftDays, 0);
    expect(d.bundle.heartRate, hasLength(2));
    expect(d.bundle.hrvIsRmssd, isTrue);
    expect(d.bundle.sleep.first.isDetailedStage, isTrue);
    expect(d.bundle.workouts.single.distanceM, 5000);
    expect(d.bundle.stepsByDay, {'2026-09-21': 9000});
    expect(d.journal['2026-09-21']!.answers, {'caffeine_late': true, 'hydrated': false});
  });

  test('rejects files that are not Wateen data', () {
    expect(() => ImportedData.parse('hello', now: DateTime(2030)), throwsA(isA<ImportFormatException>()));
    expect(() => ImportedData.parse('{"a":1}', now: DateTime(2030)), throwsA(isA<ImportFormatException>()));
    expect(() => ImportedData.parse('{"format":"wateen-raw","heartRate":[]}', now: DateTime(2030)),
        throwsA(isA<ImportFormatException>()));
    expect(() => ImportedData.parse('{"format":"wateen-raw","heartRate":[["x",1]],"workouts":[{"start":1,"end":2,"type":5}]}',
        now: DateTime(2030)), throwsA(isA<ImportFormatException>()));
  });

  test('BOM is ignored', () {
    final text = decodeImportBytes([0xEF, 0xBB, 0xBF, ..._tiny.codeUnits]);
    expect(ImportedData.parse(text, now: DateTime(2030)).bundle.heartRate, hasLength(2));
  });

  group('sample file', () {
    final now = DateTime(2026, 10, 20, 12);
    late ImportedData data;

    setUpAll(() {
      data = ImportedData.parse(File('samples/wateen-sample-data.json').readAsStringSync(), now: now);
    });

    test('is aligned so it ends today, never in the future', () {
      expect(data.dayCount, greaterThanOrEqualTo(45));
      expect(sameDay(data.last, now), isTrue);
      expect(data.last.isAfter(now), isFalse);
      expect(data.shiftDays, greaterThan(0));
      expect(data.journal.length, greaterThan(35));
      expect(data.journal.keys.map(parseDayKey).every((d) => !d.isAfter(now)), isTrue);
    });

    test('runs through the whole engine with a story to tell', () {
      final firstDay = addDays(dayOf(now), -59);
      final raw = data.slice(addDays(firstDay, -1).add(const Duration(hours: 12)), now);
      final inputs = Extractor(restHr: 55, maxHr: 187, sex: Sex.male, now: now).extract(raw, firstDay, dayOf(now));
      final metrics = Scorer(UserSettings()).score(inputs.values.toList());
      final scored = metrics.where((m) => m.recovery != null).toList();
      expect(scored.length, greaterThanOrEqualTo(36));
      expect(scored.where((m) => m.recovery! < 34).length, greaterThanOrEqualTo(4));
      expect(scored.where((m) => m.recovery! >= 67).length, greaterThanOrEqualTo(10));

      // The cold: resting heart rate far above the personal baseline.
      final sick = metrics.where((m) =>
          m.inputs.rhr != null && m.rhrBase != null && m.rhrBase!.count >= 4 && m.inputs.rhr! > m.rhrBase!.mean + 8);
      expect(sick, isNotEmpty);

      // A night without the watch: sleep from the phone, no stages.
      expect(metrics.any((m) => m.inputs.sleep != null && !m.inputs.sleep!.hasStages), isTrue);

      // The race is the hardest day.
      final maxStrain = metrics.map((m) => m.strain).reduce((a, b) => a > b ? a : b);
      expect(maxStrain, inInclusiveRange(15, 20));

      // Stress is measured on ordinary days.
      expect(metrics.where((m) => m.inputs.stress?.score != null).length, greaterThan(30));

      // Journal habits show their effects.
      final ins = {for (final i in journalInsights(data.journal, metrics)) i.questionId: i};
      expect(ins['caffeine_late']!.effect!, lessThan(0));
      expect(ins['stretching']!.effect!, greaterThan(0));
      expect(meanOf(scored.map((m) => m.recovery!.toDouble()))!, inInclusiveRange(40, 75));
    });
  });
}
