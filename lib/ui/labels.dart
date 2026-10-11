import 'package:flutter/material.dart';

import '../engine/body_age.dart';
import '../l10n/strings.dart';
import '../models/metrics.dart';
import 'format.dart';

const Map<String, (String, String)> _workoutNames = {
  'RUNNING': ('جري', 'Running'),
  'RUNNING_TREADMILL': ('جري على السير', 'Treadmill run'),
  'WALKING': ('مشي', 'Walking'),
  'WALKING_TREADMILL': ('مشي على السير', 'Treadmill walk'),
  'HIKING': ('مشي جبلي', 'Hiking'),
  'BIKING': ('دراجة', 'Cycling'),
  'BIKING_STATIONARY': ('دراجة ثابتة', 'Indoor cycling'),
  'TRADITIONAL_STRENGTH_TRAINING': ('تمارين قوة', 'Strength training'),
  'FUNCTIONAL_STRENGTH_TRAINING': ('قوة وظيفية', 'Functional strength'),
  'STRENGTH_TRAINING': ('تمارين قوة', 'Strength training'),
  'WEIGHTLIFTING': ('رفع أثقال', 'Weightlifting'),
  'CALISTHENICS': ('تمارين بوزن الجسم', 'Calisthenics'),
  'CORE_TRAINING': ('تمارين الجذع', 'Core training'),
  'CROSS_TRAINING': ('تدريب متنوع', 'Cross training'),
  'HIGH_INTENSITY_INTERVAL_TRAINING': ('تمارين متقطعة عالية الشدة', 'HIIT'),
  'MIXED_CARDIO': ('كارديو متنوع', 'Mixed cardio'),
  'ELLIPTICAL': ('جهاز الإهليلجي', 'Elliptical'),
  'ROWING': ('تجديف', 'Rowing'),
  'ROWING_MACHINE': ('جهاز التجديف', 'Rowing machine'),
  'STAIR_CLIMBING': ('صعود الدرج', 'Stair climbing'),
  'STAIR_CLIMBING_MACHINE': ('جهاز الدرج', 'Stair machine'),
  'SWIMMING': ('سباحة', 'Swimming'),
  'SWIMMING_POOL': ('سباحة في المسبح', 'Pool swim'),
  'SWIMMING_OPEN_WATER': ('سباحة في المياه المفتوحة', 'Open-water swim'),
  'SOCCER': ('كرة قدم', 'Football'),
  'BASKETBALL': ('كرة سلة', 'Basketball'),
  'VOLLEYBALL': ('كرة طائرة', 'Volleyball'),
  'TENNIS': ('تنس', 'Tennis'),
  'TABLE_TENNIS': ('تنس طاولة', 'Table tennis'),
  'SQUASH': ('إسكواش', 'Squash'),
  'BADMINTON': ('ريشة طائرة', 'Badminton'),
  'PICKLEBALL': ('بيكل بول', 'Pickleball'),
  'BOXING': ('ملاكمة', 'Boxing'),
  'KICKBOXING': ('كيك بوكسينغ', 'Kickboxing'),
  'MARTIAL_ARTS': ('فنون قتالية', 'Martial arts'),
  'YOGA': ('يوغا', 'Yoga'),
  'PILATES': ('بيلاتس', 'Pilates'),
  'FLEXIBILITY': ('مرونة', 'Flexibility'),
  'COOLDOWN': ('تهدئة', 'Cooldown'),
  'DANCING': ('رقص', 'Dance'),
  'CARDIO_DANCE': ('رقص كارديو', 'Cardio dance'),
  'GOLF': ('غولف', 'Golf'),
  'EQUESTRIAN_SPORTS': ('فروسية', 'Equestrian'),
  'CLIMBING': ('تسلّق', 'Climbing'),
  'JUMP_ROPE': ('نط الحبل', 'Jump rope'),
  'PADDLE_SPORTS': ('تجديف رياضي', 'Paddle sports'),
  'SURFING': ('ركوب الأمواج', 'Surfing'),
  'OTHER': ('نشاط آخر', 'Other activity'),
};

String workoutName(String type, bool ar) {
  final n = _workoutNames[type];
  if (n != null) return ar ? n.$1 : n.$2;
  if (ar) return 'نشاط رياضي';
  final words = type.toLowerCase().split('_');
  if (words.isEmpty) return type;
  final first = words.first;
  return [first.isEmpty ? first : first[0].toUpperCase() + first.substring(1), ...words.skip(1)].join(' ');
}

IconData workoutIcon(String type) {
  final t = type.toUpperCase();
  if (t.contains('RUN')) return Icons.directions_run;
  if (t.contains('WALK') || t.contains('HIK')) return Icons.directions_walk;
  if (t.contains('BIK') || t.contains('CYCL')) return Icons.directions_bike;
  if (t.contains('SWIM')) return Icons.pool;
  if (t.contains('SOCCER')) return Icons.sports_soccer;
  if (t.contains('BASKET')) return Icons.sports_basketball;
  if (t.contains('TENNIS') || t.contains('SQUASH') || t.contains('BADMINTON') || t.contains('PICKLE')) {
    return Icons.sports_tennis;
  }
  if (t.contains('YOGA') || t.contains('PILATES') || t.contains('FLEX') || t.contains('MIND')) {
    return Icons.self_improvement;
  }
  if (t.contains('BOX') || t.contains('MARTIAL')) return Icons.sports_mma;
  if (t.contains('STRENGTH') || t.contains('WEIGHT') || t.contains('CALISTHENICS') || t.contains('CORE')) {
    return Icons.fitness_center;
  }
  if (t.contains('ROW')) return Icons.rowing;
  return Icons.bolt;
}

String contributorName(ContributorKind k, S s) => switch (k) {
      ContributorKind.hrv => s.hrv,
      ContributorKind.rhr => s.rhr,
      ContributorKind.respiratory => s.respiratory,
      ContributorKind.sleep => s.sleepPerformanceShort,
      ContributorKind.temperature => s.temperature,
    };

String contributorValue(ContributorKind k, double? v, S s, Fmt f) {
  if (v == null) return '—';
  return switch (k) {
    ContributorKind.hrv => '${f.int0(v)} ${s.ms}',
    ContributorKind.rhr => '${f.int0(v)} ${s.bpm}',
    ContributorKind.respiratory => '${f.dec1(v)} ${s.rpm}',
    ContributorKind.sleep => f.pct(v),
    ContributorKind.temperature => '${f.dec1(v)}°',
  };
}

String ageFactorName(AgeFactor a, S s) => switch (a) {
      AgeFactor.sleepHours => s.factorSleepHours,
      AgeFactor.consistency => s.factorConsistency,
      AgeFactor.moderateMinutes => s.factorModerate,
      AgeFactor.vigorousMinutes => s.factorVigorous,
      AgeFactor.steps => s.factorSteps,
      AgeFactor.restingHr => s.factorRhr,
      AgeFactor.strength => s.factorStrength,
    };

String ageFactorValue(AgeContribution c, S s, Fmt f) => switch (c.factor) {
      AgeFactor.sleepHours => f.duration(c.value * 60),
      AgeFactor.consistency => f.pct(c.value),
      AgeFactor.moderateMinutes || AgeFactor.vigorousMinutes => '${f.int0(c.value)} ${s.minutesShort}',
      AgeFactor.steps => f.thousands(c.value),
      AgeFactor.restingHr => '${f.int0(c.value)} ${s.bpm}',
      AgeFactor.strength => f.dec1(c.value),
    };

String zoneTitle(RecoveryZone z, S s) => switch (z) {
      RecoveryZone.green => s.zoneGreen,
      RecoveryZone.yellow => s.zoneYellow,
      RecoveryZone.red => s.zoneRed,
    };

String stressLabel(double v, S s) => v < 1 ? s.stressLow : (v < 2 ? s.stressMed : s.stressHigh);
