/// Calendar helpers. All dates are local wall-clock dates.
library;

/// Midnight of the calendar day containing [t].
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Calendar-safe day arithmetic (immune to DST shifts).
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// `yyyy-mm-dd` key used for storage maps.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Whole calendar days from [a] to [b] (positive when b is later).
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Minutes since local midnight of [t]'s own day.
int minuteOfDay(DateTime t) => t.hour * 60 + t.minute;

/// Bedtime expressed as minutes after 18:00 of the previous evening, so that
/// 23:30 -> 330 and 00:30 -> 390. Values keep their order across midnight.
double bedtimeMinutes(DateTime t) {
  final m = t.hour * 60 + t.minute + t.second / 60.0;
  return m >= 18 * 60 ? m - 18 * 60 : m + 6 * 60;
}

/// Converts [bedtimeMinutes] back to minutes since midnight (0..1439).
int bedtimeToClock(double v) {
  final m = (v + 18 * 60).round() % (24 * 60);
  return m < 0 ? m + 24 * 60 : m;
}
