/// Raw samples as read from Apple Health / Health Connect (or the demo
/// generator), normalised into simple platform-independent types.
library;

enum SleepStage { inBed, asleep, awake, light, deep, rem, outOfBed, session }

SleepStage sleepStageFromName(String n) =>
    SleepStage.values.firstWhere((s) => s.name == n, orElse: () => SleepStage.asleep);

class TimedValue {
  final DateTime time;
  final double value;
  const TimedValue(this.time, this.value);
}

class SleepSegment {
  final DateTime start;
  final DateTime end;
  final SleepStage stage;
  final String source;
  const SleepSegment(this.start, this.end, this.stage, this.source);

  double get minutes => end.difference(start).inSeconds / 60.0;

  bool get isAsleep =>
      stage == SleepStage.asleep || stage == SleepStage.light || stage == SleepStage.deep || stage == SleepStage.rem;

  bool get isDetailedStage => stage == SleepStage.light || stage == SleepStage.deep || stage == SleepStage.rem;
}

/// A step-count sample covering an interval (used to detect movement).
class StepSample {
  final DateTime start;
  final DateTime end;
  final double count;
  const StepSample(this.start, this.end, this.count);
}

class WorkoutRecord {
  final DateTime start;
  final DateTime end;
  final String type;
  final double? kcal;
  final double? distanceM;
  const WorkoutRecord({required this.start, required this.end, required this.type, this.kcal, this.distanceM});
}

/// Everything fetched for one time range.
class RawBundle {
  final DateTime start;
  final DateTime end;
  final List<TimedValue> heartRate;
  final List<TimedValue> hrv;
  final bool hrvIsRmssd;
  final List<TimedValue> restingHr;
  final List<TimedValue> respiratory;
  final List<TimedValue> spo2;
  final List<TimedValue> temperature;
  final List<SleepSegment> sleep;
  final List<WorkoutRecord> workouts;
  final List<StepSample> stepSamples;

  /// Day key (yyyy-mm-dd) -> total steps.
  final Map<String, int> stepsByDay;

  /// Day key -> active kilocalories.
  final Map<String, double> activeKcalByDay;

  /// Data types that could not be read (no permission / unsupported).
  final List<String> missing;

  RawBundle({
    required this.start,
    required this.end,
    List<TimedValue>? heartRate,
    List<TimedValue>? hrv,
    this.hrvIsRmssd = false,
    List<TimedValue>? restingHr,
    List<TimedValue>? respiratory,
    List<TimedValue>? spo2,
    List<TimedValue>? temperature,
    List<SleepSegment>? sleep,
    List<WorkoutRecord>? workouts,
    List<StepSample>? stepSamples,
    Map<String, int>? stepsByDay,
    Map<String, double>? activeKcalByDay,
    List<String>? missing,
  })  : heartRate = heartRate ?? [],
        hrv = hrv ?? [],
        restingHr = restingHr ?? [],
        respiratory = respiratory ?? [],
        spo2 = spo2 ?? [],
        temperature = temperature ?? [],
        sleep = sleep ?? [],
        workouts = workouts ?? [],
        stepSamples = stepSamples ?? [],
        stepsByDay = stepsByDay ?? {},
        activeKcalByDay = activeKcalByDay ?? {},
        missing = missing ?? [];

  void sortAll() {
    int byTime(TimedValue a, TimedValue b) => a.time.compareTo(b.time);
    heartRate.sort(byTime);
    hrv.sort(byTime);
    restingHr.sort(byTime);
    respiratory.sort(byTime);
    spo2.sort(byTime);
    temperature.sort(byTime);
    sleep.sort((a, b) => a.start.compareTo(b.start));
    workouts.sort((a, b) => a.start.compareTo(b.start));
    stepSamples.sort((a, b) => a.start.compareTo(b.start));
  }
}
