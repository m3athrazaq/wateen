enum Sex { male, female }

enum DataMode { none, health, demo }

class UserSettings {
  String language;
  Sex sex;
  int birthYear;
  int? maxHrOverride;

  /// Baseline nightly sleep need in minutes.
  int sleepNeedBaseMin;

  /// Usual wake-up time, minutes after midnight.
  int wakeTimeMin;
  DataMode dataMode;
  bool onboarded;
  List<String> journalQuestions;

  UserSettings({
    this.language = 'ar',
    this.sex = Sex.male,
    this.birthYear = 1991,
    this.maxHrOverride,
    this.sleepNeedBaseMin = 450,
    this.wakeTimeMin = 390,
    this.dataMode = DataMode.none,
    this.onboarded = false,
    List<String>? journalQuestions,
  }) : journalQuestions = journalQuestions ?? List<String>.from(defaultJournalQuestions);

  static const List<String> defaultJournalQuestions = [
    'caffeine_late',
    'late_meal',
    'screen_bed',
    'hydrated',
    'work_stress',
    'reading_bed',
    'stretching',
    'smoking',
  ];

  bool get isArabic => language == 'ar';

  int ageAt(DateTime now) {
    final a = now.year - birthYear;
    return a < 10 ? 10 : (a > 100 ? 100 : a);
  }

  /// Tanaka formula unless the user set a value.
  int maxHrAt(DateTime now) => maxHrOverride ?? (208 - 0.7 * ageAt(now)).round();

  Map<String, dynamic> toJson() => {
        'language': language,
        'sex': sex.name,
        'birthYear': birthYear,
        'maxHrOverride': maxHrOverride,
        'sleepNeedBaseMin': sleepNeedBaseMin,
        'wakeTimeMin': wakeTimeMin,
        'dataMode': dataMode.name,
        'onboarded': onboarded,
        'journalQuestions': journalQuestions,
      };

  factory UserSettings.fromJson(Map<String, dynamic> j) => UserSettings(
        language: (j['language'] as String?) ?? 'ar',
        sex: Sex.values.firstWhere((s) => s.name == j['sex'], orElse: () => Sex.male),
        birthYear: (j['birthYear'] as num?)?.toInt() ?? 1991,
        maxHrOverride: (j['maxHrOverride'] as num?)?.toInt(),
        sleepNeedBaseMin: (j['sleepNeedBaseMin'] as num?)?.toInt() ?? 450,
        wakeTimeMin: (j['wakeTimeMin'] as num?)?.toInt() ?? 390,
        dataMode: DataMode.values.firstWhere((m) => m.name == j['dataMode'], orElse: () => DataMode.none),
        onboarded: (j['onboarded'] as bool?) ?? false,
        journalQuestions: (j['journalQuestions'] as List?)?.map((e) => e.toString()).toList(),
      );
}
