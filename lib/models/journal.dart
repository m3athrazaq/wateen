import '../util/dates.dart';

class JournalQuestion {
  final String id;
  final String ar;
  final String en;
  const JournalQuestion(this.id, this.ar, this.en);

  String label(bool arabic) => arabic ? ar : en;
}

/// Behaviours the user can log for a day; their effect is measured on the
/// next morning's recovery.
const List<JournalQuestion> allJournalQuestions = [
  JournalQuestion('caffeine_late', 'كافيين بعد الساعة 2 ظهراً', 'Caffeine after 2 PM'),
  JournalQuestion('late_meal', 'وجبة ثقيلة قبل النوم بأقل من 3 ساعات', 'Heavy meal within 3h of bed'),
  JournalQuestion('screen_bed', 'الجوال في السرير', 'Phone in bed'),
  JournalQuestion('hydrated', 'شربت ماءً كافياً (2 لتر أو أكثر)', 'Drank 2L+ of water'),
  JournalQuestion('work_stress', 'ضغط عمل مرتفع', 'High work stress'),
  JournalQuestion('reading_bed', 'قراءة قبل النوم', 'Reading before bed'),
  JournalQuestion('stretching', 'تمدد أو تمارين تنفس', 'Stretching or breathwork'),
  JournalQuestion('smoking', 'تدخين أو شيشة', 'Smoking or shisha'),
  JournalQuestion('energy_drink', 'مشروب طاقة', 'Energy drink'),
  JournalQuestion('fasting', 'صيام', 'Fasting'),
  JournalQuestion('late_workout', 'تمرين بعد الساعة 9 مساءً', 'Workout after 9 PM'),
  JournalQuestion('travel', 'سفر', 'Travel'),
  JournalQuestion('sick', 'شعور بالمرض', 'Feeling sick'),
  JournalQuestion('sauna', 'ساونا أو حمام ساخن', 'Sauna or hot bath'),
  JournalQuestion('nap', 'قيلولة', 'Took a nap'),
  JournalQuestion('outdoor_light', 'تعرّض لضوء الشمس صباحاً', 'Morning sunlight'),
];

JournalQuestion? questionById(String id) {
  for (final q in allJournalQuestions) {
    if (q.id == id) return q;
  }
  return null;
}

class JournalEntry {
  final DateTime date;
  final Map<String, bool> answers;
  const JournalEntry(this.date, this.answers);

  String get key => dayKey(date);

  JournalEntry withAnswer(String id, bool? value) {
    final next = Map<String, bool>.from(answers);
    if (value == null) {
      next.remove(id);
    } else {
      next[id] = value;
    }
    return JournalEntry(date, next);
  }

  Map<String, dynamic> toJson() => {'date': key, 'a': answers};

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        parseDayKey(j['date'] as String),
        Map<String, dynamic>.from((j['a'] as Map?) ?? const {}).map((k, v) => MapEntry(k, v == true)),
      );
}
