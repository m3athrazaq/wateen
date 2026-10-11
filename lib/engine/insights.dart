import '../models/journal.dart';
import '../models/metrics.dart';
import '../util/dates.dart';
import '../util/stats.dart';

class JournalInsight {
  final String questionId;
  final int yesCount;
  final int noCount;
  final double? yesMean;
  final double? noMean;

  const JournalInsight(this.questionId, this.yesCount, this.noCount, this.yesMean, this.noMean);

  static const int minEach = 3;

  bool get enoughData => yesCount >= minEach && noCount >= minEach;

  /// Difference in next-morning recovery (percentage points), yes minus no.
  double? get effect => (yesMean != null && noMean != null) ? yesMean! - noMean! : null;
}

/// Compares next-day recovery after days answered "yes" vs "no".
List<JournalInsight> journalInsights(Map<String, JournalEntry> journal, List<DayMetrics> metrics) {
  final recoveryByKey = <String, int>{};
  for (final m in metrics) {
    if (m.recovery != null) recoveryByKey[m.inputs.key] = m.recovery!;
  }
  final yes = <String, List<double>>{};
  final no = <String, List<double>>{};
  for (final e in journal.values) {
    final next = recoveryByKey[dayKey(addDays(e.date, 1))];
    if (next == null) continue;
    e.answers.forEach((id, v) {
      (v ? yes : no).putIfAbsent(id, () => []).add(next.toDouble());
    });
  }
  final ids = {...yes.keys, ...no.keys};
  final out = [
    for (final id in ids)
      JournalInsight(id, yes[id]?.length ?? 0, no[id]?.length ?? 0, meanOf(yes[id] ?? const []),
          meanOf(no[id] ?? const [])),
  ];
  out.sort((a, b) {
    if (a.enoughData != b.enoughData) return a.enoughData ? -1 : 1;
    return (b.effect?.abs() ?? 0).compareTo(a.effect?.abs() ?? 0);
  });
  return out;
}
