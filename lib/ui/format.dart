/// Locale-aware formatting that does not depend on intl date symbols.
class Fmt {
  final bool ar;
  const Fmt(this.ar);

  static const _weekdaysAr = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _weekdaysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _weekdayShortAr = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
  static const _weekdayShortEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _monthsAr = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  static const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String weekday(DateTime d) => (ar ? _weekdaysAr : _weekdaysEn)[d.weekday - 1];

  String weekdayShort(DateTime d) => (ar ? _weekdayShortAr : _weekdayShortEn)[d.weekday - 1];

  String month(int m) => (ar ? _monthsAr : _monthsEn)[m - 1];

  /// "السبت 10 أكتوبر" / "Saturday, Oct 10"
  String dateLong(DateTime d) => ar ? '${weekday(d)} ${d.day} ${month(d.month)}' : '${weekday(d)}, ${month(d.month)} ${d.day}';

  /// "10 أكتوبر" / "Oct 10"
  String dateShort(DateTime d) => ar ? '${d.day} ${month(d.month)}' : '${month(d.month)} ${d.day}';

  /// 12-hour clock: "10:48 م" / "10:48 PM"
  String clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final suffix = t.hour < 12 ? (ar ? 'ص' : 'AM') : (ar ? 'م' : 'PM');
    return '$h:$m $suffix';
  }

  String clockMinutes(int minutesOfDay) {
    final m = ((minutesOfDay % 1440) + 1440) % 1440;
    return clock(DateTime(2000, 1, 1, m ~/ 60, m % 60));
  }

  /// "7س 32د" / "7h 32m"
  String duration(double minutes) {
    final total = minutes.round();
    final h = total ~/ 60;
    final m = total % 60;
    if (ar) return h > 0 ? '${h}س ${m}د' : '${m}د';
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String hours(double minutes) => (minutes / 60).toStringAsFixed(1);

  String int0(num v) => v.round().toString();

  String dec1(num v) => v.toStringAsFixed(1);

  String pct(num v) => '${v.round()}%';

  /// Signed value with a real minus sign.
  String signed(num v, {int digits = 0}) {
    final s = v.abs().toStringAsFixed(digits);
    if (v.abs() < 0.5 * _unit(digits)) return s;
    return v > 0 ? '+$s' : '−$s';
  }

  static double _unit(int digits) {
    var u = 1.0;
    for (var i = 0; i < digits; i++) {
      u /= 10;
    }
    return u;
  }

  String thousands(num v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
