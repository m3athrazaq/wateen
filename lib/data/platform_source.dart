import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../models/raw.dart';
import '../util/dates.dart';
import 'health_source.dart';

/// Reads from Apple Health (iOS) or Health Connect (Android).
class PlatformHealthSource implements HealthSource {
  final Health _health = Health();
  bool _configured = false;
  bool _skinTempAvailable = false;

  static const List<HealthDataType> _iosTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_WRIST_TEMPERATURE,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
  ];

  /// Distance and total calories are requested because Health Connect reads
  /// them while assembling workouts.
  static const List<HealthDataType> _androidTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_AWAKE_IN_BED,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_OUT_OF_BED,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WORKOUT,
  ];

  static const List<HealthDataType> _iosSleep = [
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];

  static const List<HealthDataType> _androidSleep = [
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_AWAKE_IN_BED,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_OUT_OF_BED,
  ];

  Future<void> _ensure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
    if (Platform.isAndroid) {
      try {
        _skinTempAvailable = await _health.isSkinTemperatureAvailable();
      } catch (_) {
        _skinTempAvailable = false;
      }
    }
  }

  List<HealthDataType> get _types => Platform.isIOS
      ? _iosTypes
      : [..._androidTypes, if (_skinTempAvailable) HealthDataType.SKIN_TEMPERATURE];

  @override
  Future<ConnectStatus> connect() async {
    if (!Platform.isIOS && !Platform.isAndroid) return ConnectStatus.unsupported;
    await _ensure();
    if (Platform.isAndroid) {
      final status = await _health.getHealthConnectSdkStatus();
      if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        return ConnectStatus.needsHealthConnectUpdate;
      }
      if (status != HealthConnectSdkStatus.sdkAvailable) return ConnectStatus.needsHealthConnect;
    }
    final types = _types;
    var ok = false;
    try {
      final has = Platform.isAndroid ? await _health.hasPermissions(types) : null;
      ok = has == true ? true : await _health.requestAuthorization(types);
    } catch (e) {
      debugPrint('Wateen: authorization failed: $e');
    }
    if (Platform.isAndroid) {
      try {
        if (await _health.isHealthDataHistoryAvailable() && !await _health.isHealthDataHistoryAuthorized()) {
          await _health.requestHealthDataHistoryAuthorization();
        }
      } catch (e) {
        debugPrint('Wateen: history permission failed: $e');
      }
      if (!ok) {
        try {
          ok = await _health.hasPermissions([HealthDataType.HEART_RATE]) ?? false;
        } catch (_) {}
      }
      return ok ? ConnectStatus.connected : ConnectStatus.denied;
    }
    // iOS never reveals whether read access was granted.
    return ConnectStatus.connected;
  }

  Future<void> installHealthConnect() => _health.installHealthConnect();

  @override
  Future<RawBundle> fetch(DateTime start, DateTime end) async {
    await _ensure();
    final ios = Platform.isIOS;
    final missing = <String>[];
    final bundle = RawBundle(start: start, end: end, hrvIsRmssd: !ios, missing: missing);

    Future<List<HealthDataPoint>> get(HealthDataType t, DateTime s, DateTime e) async {
      try {
        return await _health.getHealthDataFromTypes(types: [t], startTime: s, endTime: e);
      } catch (err) {
        if (!missing.contains(t.name)) missing.add(t.name);
        debugPrint('Wateen: reading ${t.name} failed: $err');
        return const <HealthDataPoint>[];
      }
    }

    // Dense types are read week by week to keep each platform call small.
    Future<List<HealthDataPoint>> chunked(HealthDataType t) async {
      final out = <HealthDataPoint>[];
      var s = start;
      while (s.isBefore(end)) {
        var e = s.add(const Duration(days: 7));
        if (e.isAfter(end)) e = end;
        out.addAll(await get(t, s, e));
        s = e;
      }
      return out;
    }

    bundle.heartRate.addAll(_values(await chunked(HealthDataType.HEART_RATE)));
    bundle.hrv.addAll(_values(await get(
        ios ? HealthDataType.HEART_RATE_VARIABILITY_SDNN : HealthDataType.HEART_RATE_VARIABILITY_RMSSD, start, end)));
    bundle.restingHr.addAll(_values(await get(HealthDataType.RESTING_HEART_RATE, start, end)));
    bundle.respiratory.addAll(_values(await get(HealthDataType.RESPIRATORY_RATE, start, end)));
    bundle.spo2.addAll(_values(await get(HealthDataType.BLOOD_OXYGEN, start, end)));

    if (ios) {
      bundle.temperature.addAll(_values(await get(HealthDataType.SLEEP_WRIST_TEMPERATURE, start, end)));
    } else if (_skinTempAvailable) {
      for (final p in await get(HealthDataType.SKIN_TEMPERATURE, start, end)) {
        final v = p.value;
        if (v is SkinTemperatureHealthValue) {
          bundle.temperature.add(TimedValue(p.dateFrom, v.temperatureDelta));
        } else if (v is NumericHealthValue) {
          bundle.temperature.add(TimedValue(p.dateFrom, v.numericValue.toDouble()));
        }
      }
    }

    for (final t in ios ? _iosSleep : _androidSleep) {
      final stage = _stageOf(t);
      for (final p in await get(t, start, end)) {
        bundle.sleep.add(SleepSegment(p.dateFrom, p.dateTo, stage, _sourceOf(p)));
      }
    }

    for (final p in await get(HealthDataType.WORKOUT, start, end)) {
      final v = p.value;
      if (v is! WorkoutHealthValue) continue;
      bundle.workouts.add(WorkoutRecord(
        start: p.dateFrom,
        end: p.dateTo,
        type: v.workoutActivityType.name,
        kcal: v.totalEnergyBurned?.toDouble(),
        distanceM: v.totalDistance?.toDouble(),
      ));
    }

    for (final p in await chunked(HealthDataType.STEPS)) {
      final v = p.value;
      if (v is NumericHealthValue) {
        bundle.stepSamples.add(StepSample(p.dateFrom, p.dateTo, v.numericValue.toDouble()));
      }
    }

    // Daily totals: the platform's own aggregation removes phone/watch overlap.
    for (var d = dayOf(start); !d.isAfter(dayOf(end)); d = addDays(d, 1)) {
      final dayEnd = addDays(d, 1).isAfter(end) ? end : addDays(d, 1);
      if (!dayEnd.isAfter(d)) continue;
      try {
        final steps = await _health.getTotalStepsInInterval(d, dayEnd);
        if (steps != null) bundle.stepsByDay[dayKey(d)] = steps;
      } catch (e) {
        if (!missing.contains('STEPS_TOTAL')) missing.add('STEPS_TOTAL');
      }
    }

    // Active energy: sum per source per day and keep the largest source to
    // avoid double counting phone and watch.
    final perSource = <String, Map<String, double>>{};
    for (final p in await chunked(HealthDataType.ACTIVE_ENERGY_BURNED)) {
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      final day = dayKey(p.dateFrom);
      final src = perSource.putIfAbsent(day, () => <String, double>{});
      final key = _sourceOf(p);
      src[key] = (src[key] ?? 0.0) + v.numericValue.toDouble();
    }
    perSource.forEach((day, sources) {
      bundle.activeKcalByDay[day] = sources.values.fold(0.0, (a, b) => math.max(a, b));
    });

    bundle.sortAll();
    return bundle;
  }

  static Iterable<TimedValue> _values(List<HealthDataPoint> points) sync* {
    for (final p in points) {
      final v = p.value;
      if (v is NumericHealthValue) yield TimedValue(p.dateFrom, v.numericValue.toDouble());
    }
  }

  static String _sourceOf(HealthDataPoint p) => p.sourceId.isNotEmpty ? p.sourceId : p.sourceName;

  static SleepStage _stageOf(HealthDataType t) {
    switch (t) {
      case HealthDataType.SLEEP_IN_BED:
        return SleepStage.inBed;
      case HealthDataType.SLEEP_AWAKE:
      case HealthDataType.SLEEP_AWAKE_IN_BED:
        return SleepStage.awake;
      case HealthDataType.SLEEP_LIGHT:
        return SleepStage.light;
      case HealthDataType.SLEEP_DEEP:
        return SleepStage.deep;
      case HealthDataType.SLEEP_REM:
        return SleepStage.rem;
      case HealthDataType.SLEEP_OUT_OF_BED:
        return SleepStage.outOfBed;
      case HealthDataType.SLEEP_SESSION:
        return SleepStage.session;
      default:
        return SleepStage.asleep;
    }
  }
}
