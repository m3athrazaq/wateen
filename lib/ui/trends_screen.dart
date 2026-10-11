import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/metrics.dart';
import '../util/dates.dart';
import '../util/stats.dart';
import 'ctx.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';

enum TrendMetric { recovery, hrv, rhr, sleepHours, sleepScore, strain, steps, stress, respiratory }

class _Spec {
  final String name;
  final double? Function(DayMetrics) value;
  final bool bars;
  final Color color;
  final double? maxY;
  final String Function(double) format;

  /// Whether a higher value is better (for colouring the change).
  final bool higherIsBetter;
  final Color Function(double?)? colorOf;

  const _Spec({
    required this.name,
    required this.value,
    required this.bars,
    required this.color,
    this.maxY,
    required this.format,
    this.higherIsBetter = true,
    this.colorOf,
  });
}

_Spec _spec(TrendMetric t, S s, Fmt f) => switch (t) {
      TrendMetric.recovery => _Spec(
          name: s.recovery,
          value: (m) => m.recovery?.toDouble(),
          bars: true,
          color: WColors.palm,
          maxY: 100,
          format: (v) => f.pct(v),
          colorOf: (v) => WColors.recovery(v?.round()),
        ),
      TrendMetric.hrv => _Spec(
          name: s.hrv,
          value: (m) => m.inputs.hrv,
          bars: false,
          color: WColors.palm,
          format: (v) => '${f.int0(v)} ${s.ms}',
        ),
      TrendMetric.rhr => _Spec(
          name: s.rhr,
          value: (m) => m.inputs.rhr,
          bars: false,
          color: WColors.madder,
          format: (v) => '${f.int0(v)} ${s.bpm}',
          higherIsBetter: false,
        ),
      TrendMetric.sleepHours => _Spec(
          name: s.sleepHours,
          value: (m) => m.inputs.sleep == null ? null : m.inputs.sleep!.asleepMin / 60,
          bars: true,
          color: WColors.lavender,
          format: (v) => f.duration(v * 60),
        ),
      TrendMetric.sleepScore => _Spec(
          name: s.sleepScore,
          value: (m) => m.sleepScore,
          bars: true,
          color: WColors.lavender,
          maxY: 100,
          format: (v) => f.pct(v),
        ),
      TrendMetric.strain => _Spec(
          name: s.strain,
          value: (m) => m.inputs.hasAnyData ? m.strain : null,
          bars: true,
          color: WColors.indigo,
          maxY: 21,
          format: (v) => f.dec1(v),
        ),
      TrendMetric.steps => _Spec(
          name: s.steps,
          value: (m) => m.inputs.steps?.toDouble(),
          bars: true,
          color: WColors.calm,
          format: (v) => f.thousands(v),
        ),
      TrendMetric.stress => _Spec(
          name: s.stress,
          value: (m) => m.inputs.stress?.score,
          bars: true,
          color: WColors.stress,
          maxY: 3,
          format: (v) => f.dec1(v),
          higherIsBetter: false,
          colorOf: (v) => WColors.stressLevel(v),
        ),
      TrendMetric.respiratory => _Spec(
          name: s.respiratory,
          value: (m) => m.inputs.respiratory,
          bars: false,
          color: WColors.calm,
          format: (v) => '${f.dec1(v)} ${s.rpm}',
          higherIsBetter: false,
        ),
    };

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  int _days = 30;
  TrendMetric _metric = TrendMetric.recovery;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final today = dayOf(DateTime.now());
    final spec = _spec(_metric, s, f);

    final days = [for (var i = _days - 1; i >= 0; i--) addDays(today, -i)];
    final values = [for (final d in days) _valueOn(app.metricsFor(d), spec)];
    final prevValues = [for (final d in days) _valueOn(app.metricsFor(addDays(d, -_days)), spec)];
    final avg = meanOf(values.whereType<double>());
    final prevAvg = meanOf(prevValues.whereType<double>());

    List<String> labels;
    if (_days <= 7) {
      labels = [for (final d in days) f.weekdayShort(d)];
    } else {
      labels = [for (final d in days) f.dateShort(d)];
    }

    double? bandLo;
    double? bandHi;
    final latest = app.latest;
    if (latest != null) {
      if (_metric == TrendMetric.hrv && latest.hrvBase != null && latest.hrvBase!.count >= 4) {
        bandLo = math.exp(latest.hrvBase!.mean - latest.hrvBase!.sd);
        bandHi = math.exp(latest.hrvBase!.mean + latest.hrvBase!.sd);
      } else if (_metric == TrendMetric.rhr && latest.rhrBase != null && latest.rhrBase!.count >= 4) {
        bandLo = latest.rhrBase!.mean - latest.rhrBase!.sd;
        bandHi = latest.rhrBase!.mean + latest.rhrBase!.sd;
      } else if (_metric == TrendMetric.respiratory && latest.rrBase != null && latest.rrBase!.count >= 4) {
        bandLo = latest.rrBase!.mean - latest.rrBase!.sd;
        bandHi = latest.rrBase!.mean + latest.rrBase!.sd;
      }
    }

    Widget chart;
    if (values.whereType<double>().isEmpty) {
      chart = SizedBox(height: 160, child: Center(child: Text(s.noTrendData, style: WText.bodyDim)));
    } else if (spec.bars) {
      chart = BarChart(
        values: values,
        colors: [for (final v in values) spec.colorOf?.call(v) ?? spec.color],
        labels: labels,
        maxY: spec.maxY,
        height: 180,
        showValues: _days <= 7,
        format: spec.format,
        reference: avg,
      );
    } else {
      chart = LineChart(values: values, color: spec.color, labels: labels, bandLo: bandLo, bandHi: bandHi, height: 180);
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.tabTrends)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _WeekReport(),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 7, label: Text(s.days7)),
              ButtonSegment(value: 30, label: Text(s.days30)),
              ButtonSegment(value: 90, label: Text(s.days90)),
            ],
            selected: {_days},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _days = v.first),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final t in TrendMetric.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(_spec(t, s, f).name),
                      selected: t == _metric,
                      onSelected: (_) => setState(() => _metric = t),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Stat(label: s.average, value: avg == null ? '—' : spec.format(avg)),
                    ),
                    if (avg != null && prevAvg != null) _Change(avg: avg, prev: prevAvg, spec: spec),
                  ],
                ),
                const SizedBox(height: 16),
                chart,
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double? _valueOn(DayMetrics? m, _Spec spec) => m == null ? null : spec.value(m);
}

class _Change extends StatelessWidget {
  final double avg;
  final double prev;
  final _Spec spec;
  const _Change({required this.avg, required this.prev, required this.spec});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final f = context.fmt;
    final diff = avg - prev;
    final pct = prev == 0 ? 0.0 : diff / prev * 100;
    final good = spec.higherIsBetter ? diff >= 0 : diff <= 0;
    final color = pct.abs() < 2 ? WColors.ash : (good ? WColors.palm : WColors.madder);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${f.signed(pct)}%', style: WText.number.copyWith(fontSize: 18, color: color)),
        Text(s.vsPrevious, style: WText.small),
      ],
    );
  }
}

class _WeekReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final today = dayOf(DateTime.now());
    final thisWeek = [for (var i = 0; i < 7; i++) app.metricsFor(addDays(today, -i))].whereType<DayMetrics>().toList();
    final lastWeek = [for (var i = 7; i < 14; i++) app.metricsFor(addDays(today, -i))].whereType<DayMetrics>().toList();

    double? avg(List<DayMetrics> l, double? Function(DayMetrics) g) => meanOf(l.map(g).whereType<double>());
    int workouts(List<DayMetrics> l) => l.fold(0, (a, m) => a + m.inputs.workouts.length);

    Widget cell(String label, double? now, double? before, String Function(double) fmt, {bool higherBetter = true}) {
      String? delta;
      Color color = WColors.ash;
      if (now != null && before != null) {
        final d = now - before;
        delta = f.signed(d, digits: d.abs() < 10 ? 1 : 0);
        final good = higherBetter ? d >= 0 : d <= 0;
        color = good ? WColors.palm : WColors.madder;
      }
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: WText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(now == null ? '—' : fmt(now), style: WText.number.copyWith(fontSize: 19)),
            if (delta != null) Text(delta, style: WText.small.copyWith(color: color)),
          ],
        ),
      );
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.weekReport, style: WText.title.copyWith(fontSize: 16)),
          Text(s.weekReportSub, style: WText.small),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cell(s.recovery, avg(thisWeek, (m) => m.recovery?.toDouble()), avg(lastWeek, (m) => m.recovery?.toDouble()),
                  (v) => f.pct(v)),
              cell(s.sleep, avg(thisWeek, (m) => m.inputs.sleep?.asleepMin), avg(lastWeek, (m) => m.inputs.sleep?.asleepMin),
                  (v) => f.duration(v)),
              cell(s.strain, avg(thisWeek, (m) => m.inputs.hasAnyData ? m.strain : null),
                  avg(lastWeek, (m) => m.inputs.hasAnyData ? m.strain : null), (v) => f.dec1(v)),
              cell(s.workouts, workouts(thisWeek).toDouble(), workouts(lastWeek).toDouble(), (v) => f.int0(v)),
            ],
          ),
        ],
      ),
    );
  }
}
