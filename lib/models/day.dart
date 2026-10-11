import '../util/dates.dart';
import 'raw.dart';

DateTime _t(dynamic ms) => DateTime.fromMillisecondsSinceEpoch((ms as num).toInt());
double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

class StageSpan {
  final DateTime start;
  final DateTime end;
  final SleepStage stage;
  const StageSpan(this.start, this.end, this.stage);

  double get minutes => end.difference(start).inSeconds / 60.0;

  List<dynamic> toJson() => [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch, stage.index];

  factory StageSpan.fromJson(List<dynamic> j) =>
      StageSpan(_t(j[0]), _t(j[1]), SleepStage.values[(j[2] as num).toInt()]);
}

class SleepSummary {
  final DateTime start;
  final DateTime end;
  final double asleepMin;
  final double inBedMin;
  final double awakeMin;
  final double lightMin;
  final double deepMin;
  final double remMin;
  final bool hasStages;
  final int disturbances;
  final List<StageSpan> spans;

  const SleepSummary({
    required this.start,
    required this.end,
    required this.asleepMin,
    required this.inBedMin,
    required this.awakeMin,
    required this.lightMin,
    required this.deepMin,
    required this.remMin,
    required this.hasStages,
    required this.disturbances,
    this.spans = const [],
  });

  double get efficiency => inBedMin <= 0 ? 0 : (asleepMin / inBedMin).clamp(0.0, 1.0).toDouble();

  double get restorativeMin => deepMin + remMin;

  SleepSummary withoutSpans() => SleepSummary(
        start: start,
        end: end,
        asleepMin: asleepMin,
        inBedMin: inBedMin,
        awakeMin: awakeMin,
        lightMin: lightMin,
        deepMin: deepMin,
        remMin: remMin,
        hasStages: hasStages,
        disturbances: disturbances,
      );

  Map<String, dynamic> toJson() => {
        's': start.millisecondsSinceEpoch,
        'e': end.millisecondsSinceEpoch,
        'as': asleepMin,
        'ib': inBedMin,
        'aw': awakeMin,
        'li': lightMin,
        'de': deepMin,
        're': remMin,
        'hs': hasStages,
        'di': disturbances,
        'sp': spans.map((s) => s.toJson()).toList(),
      };

  factory SleepSummary.fromJson(Map<String, dynamic> j) => SleepSummary(
        start: _t(j['s']),
        end: _t(j['e']),
        asleepMin: _d(j['as']) ?? 0.0,
        inBedMin: _d(j['ib']) ?? 0.0,
        awakeMin: _d(j['aw']) ?? 0.0,
        lightMin: _d(j['li']) ?? 0.0,
        deepMin: _d(j['de']) ?? 0.0,
        remMin: _d(j['re']) ?? 0.0,
        hasStages: (j['hs'] as bool?) ?? false,
        disturbances: (j['di'] as num?)?.toInt() ?? 0,
        spans: ((j['sp'] as List?) ?? const []).map((e) => StageSpan.fromJson(e as List<dynamic>)).toList(),
      );
}

class NapSummary {
  final DateTime start;
  final DateTime end;
  final double asleepMin;
  const NapSummary(this.start, this.end, this.asleepMin);

  Map<String, dynamic> toJson() => {'s': start.millisecondsSinceEpoch, 'e': end.millisecondsSinceEpoch, 'a': asleepMin};

  factory NapSummary.fromJson(Map<String, dynamic> j) => NapSummary(_t(j['s']), _t(j['e']), _d(j['a']) ?? 0.0);
}

class WorkoutSummary {
  final DateTime start;
  final DateTime end;
  final String type;
  final double? kcal;
  final double? distanceM;
  final double trimp;
  final double? avgHr;
  final double? maxHr;

  const WorkoutSummary({
    required this.start,
    required this.end,
    required this.type,
    this.kcal,
    this.distanceM,
    required this.trimp,
    this.avgHr,
    this.maxHr,
  });

  double get minutes => end.difference(start).inSeconds / 60.0;

  Map<String, dynamic> toJson() => {
        's': start.millisecondsSinceEpoch,
        'e': end.millisecondsSinceEpoch,
        't': type,
        'k': kcal,
        'd': distanceM,
        'tr': trimp,
        'ah': avgHr,
        'mh': maxHr,
      };

  factory WorkoutSummary.fromJson(Map<String, dynamic> j) => WorkoutSummary(
        start: _t(j['s']),
        end: _t(j['e']),
        type: (j['t'] as String?) ?? 'OTHER',
        kcal: _d(j['k']),
        distanceM: _d(j['d']),
        trimp: _d(j['tr']) ?? 0.0,
        avgHr: _d(j['ah']),
        maxHr: _d(j['mh']),
      );
}

class StressSummary {
  /// Time-weighted average on the 0..3 scale. Null when there was too little data.
  final double? score;
  final double lowMin;
  final double medMin;
  final double highMin;

  /// Half-hour buckets starting at [bucketStart]; null where no data.
  final List<double?> buckets;
  final DateTime? bucketStart;

  const StressSummary({
    required this.score,
    required this.lowMin,
    required this.medMin,
    required this.highMin,
    this.buckets = const [],
    this.bucketStart,
  });

  double get totalMin => lowMin + medMin + highMin;

  StressSummary withoutBuckets() =>
      StressSummary(score: score, lowMin: lowMin, medMin: medMin, highMin: highMin);

  Map<String, dynamic> toJson() => {
        'sc': score,
        'lo': lowMin,
        'me': medMin,
        'hi': highMin,
        'b': buckets,
        'bs': bucketStart?.millisecondsSinceEpoch,
      };

  factory StressSummary.fromJson(Map<String, dynamic> j) => StressSummary(
        score: _d(j['sc']),
        lowMin: _d(j['lo']) ?? 0.0,
        medMin: _d(j['me']) ?? 0.0,
        highMin: _d(j['hi']) ?? 0.0,
        buckets: ((j['b'] as List?) ?? const []).map((e) => _d(e)).toList(),
        bucketStart: j['bs'] == null ? null : _t(j['bs']),
      );
}

class HrPoint {
  final DateTime time;
  final double bpm;
  const HrPoint(this.time, this.bpm);
}

/// Everything extracted from raw samples for one day. A "day" runs from the
/// main sleep's wake-up until the next main sleep starts.
class DayInputs {
  final DateTime date;
  final SleepSummary? sleep;
  final List<NapSummary> naps;
  final double? hrv;
  final bool hrvIsRmssd;
  final double? rhr;
  final bool rhrFromSleep;
  final double? respiratory;
  final double? spo2;
  final double? temperature;
  final int? steps;
  final double? activeKcal;
  final double trimp;

  /// Minutes below zone 1 (index 0) and in zones 1..5 (indexes 1..5).
  final List<double> zoneMinutes;
  final double? avgHr;
  final double? maxHr;
  final DateTime windowStart;
  final DateTime windowEnd;
  final bool windowComplete;
  final List<WorkoutSummary> workouts;
  final StressSummary? stress;
  final List<HrPoint> hrSeries;

  const DayInputs({
    required this.date,
    this.sleep,
    this.naps = const [],
    this.hrv,
    this.hrvIsRmssd = false,
    this.rhr,
    this.rhrFromSleep = false,
    this.respiratory,
    this.spo2,
    this.temperature,
    this.steps,
    this.activeKcal,
    this.trimp = 0,
    this.zoneMinutes = const [0, 0, 0, 0, 0, 0],
    this.avgHr,
    this.maxHr,
    required this.windowStart,
    required this.windowEnd,
    this.windowComplete = true,
    this.workouts = const [],
    this.stress,
    this.hrSeries = const [],
  });

  String get key => dayKey(date);

  double get napMinutes => naps.fold(0.0, (a, n) => a + n.asleepMin);

  bool get hasAnyData =>
      sleep != null ||
      hrv != null ||
      rhr != null ||
      trimp > 0 ||
      (steps ?? 0) > 0 ||
      workouts.isNotEmpty ||
      hrSeries.isNotEmpty;

  /// A lighter copy for older days (drops chart-only detail).
  DayInputs lite() => DayInputs(
        date: date,
        sleep: sleep?.withoutSpans(),
        naps: naps,
        hrv: hrv,
        hrvIsRmssd: hrvIsRmssd,
        rhr: rhr,
        rhrFromSleep: rhrFromSleep,
        respiratory: respiratory,
        spo2: spo2,
        temperature: temperature,
        steps: steps,
        activeKcal: activeKcal,
        trimp: trimp,
        zoneMinutes: zoneMinutes,
        avgHr: avgHr,
        maxHr: maxHr,
        windowStart: windowStart,
        windowEnd: windowEnd,
        windowComplete: windowComplete,
        workouts: workouts,
        stress: stress?.withoutBuckets(),
      );

  Map<String, dynamic> toJson() => {
        'date': key,
        'sl': sleep?.toJson(),
        'na': naps.map((n) => n.toJson()).toList(),
        'hv': hrv,
        'hr2': hrvIsRmssd,
        'rh': rhr,
        'rs': rhrFromSleep,
        'rr': respiratory,
        'o2': spo2,
        'tp': temperature,
        'st': steps,
        'kc': activeKcal,
        'tr': trimp,
        'zm': zoneMinutes,
        'ah': avgHr,
        'mh': maxHr,
        'ws': windowStart.millisecondsSinceEpoch,
        'we': windowEnd.millisecondsSinceEpoch,
        'wc': windowComplete,
        'wo': workouts.map((w) => w.toJson()).toList(),
        'ss': stress?.toJson(),
        'hs': hrSeries.map((p) => [p.time.millisecondsSinceEpoch, p.bpm]).toList(),
      };

  factory DayInputs.fromJson(Map<String, dynamic> j) {
    final zm = ((j['zm'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList();
    while (zm.length < 6) {
      zm.add(0);
    }
    return DayInputs(
      date: parseDayKey(j['date'] as String),
      sleep: j['sl'] == null ? null : SleepSummary.fromJson(Map<String, dynamic>.from(j['sl'] as Map)),
      naps: ((j['na'] as List?) ?? const [])
          .map((e) => NapSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hrv: _d(j['hv']),
      hrvIsRmssd: (j['hr2'] as bool?) ?? false,
      rhr: _d(j['rh']),
      rhrFromSleep: (j['rs'] as bool?) ?? false,
      respiratory: _d(j['rr']),
      spo2: _d(j['o2']),
      temperature: _d(j['tp']),
      steps: (j['st'] as num?)?.toInt(),
      activeKcal: _d(j['kc']),
      trimp: _d(j['tr']) ?? 0.0,
      zoneMinutes: zm,
      avgHr: _d(j['ah']),
      maxHr: _d(j['mh']),
      windowStart: _t(j['ws']),
      windowEnd: _t(j['we']),
      windowComplete: (j['wc'] as bool?) ?? true,
      workouts: ((j['wo'] as List?) ?? const [])
          .map((e) => WorkoutSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      stress: j['ss'] == null ? null : StressSummary.fromJson(Map<String, dynamic>.from(j['ss'] as Map)),
      hrSeries: ((j['hs'] as List?) ?? const [])
          .map((e) => HrPoint(_t((e as List)[0]), (e[1] as num).toDouble()))
          .toList(),
    );
  }
}
