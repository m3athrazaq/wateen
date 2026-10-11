import 'package:flutter/material.dart';

import '../engine/strain_model.dart';
import '../models/day.dart';
import '../util/dates.dart';
import 'ctx.dart';
import 'labels.dart';
import 'theme.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';
import 'widgets/ring.dart';

class StrainScreen extends StatelessWidget {
  final DateTime day;
  const StrainScreen({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final m = app.metricsFor(day);
    if (m == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.strain)),
        body: EmptyNote(icon: Icons.bolt, title: s.noDataTitle, body: s.noDataBody),
      );
    }
    final i = m.inputs;
    final maxHr = app.settings.maxHrAt(DateTime.now()).toDouble();
    final week = [for (var k = 6; k >= 0; k--) app.metricsFor(addDays(day, -k))];

    String status;
    if (m.strain < m.targetLo) {
      status = s.strainBelow;
    } else if (m.strain <= m.targetHi) {
      status = s.strainWithin;
    } else {
      status = s.strainAbove;
    }

    final zoneTotal = i.zoneMinutes.skip(1).fold(0.0, (a, b) => a + b);
    const ranges = [(50, 60), (60, 70), (70, 80), (80, 90), (90, 100)];

    return Scaffold(
      appBar: AppBar(title: Text(s.strain)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: WovenRing(
              value: m.strain / 21,
              color: WColors.indigo,
              size: 210,
              bandFrom: m.targetLo / 21,
              bandTo: m.targetHi / 21,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(f.dec1(m.strain), style: WText.hero.copyWith(fontSize: 50)),
                  Text(s.dayStrain, style: WText.label),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(s.targetRange(f.int0(m.targetLo), f.int0(m.targetHi)), style: WText.title, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(i.windowComplete ? status : '${s.dayInProgress}. $status', style: WText.bodyDim, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (i.hrSeries.isNotEmpty) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PanelTitle(s.heartRate),
                  HeartRateChart(points: i.hrSeries, start: i.windowStart, end: i.windowEnd, maxHr: maxHr, fmt: f),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Stat(label: s.avgHr, value: i.avgHr == null ? '—' : f.int0(i.avgHr!), sub: s.bpm)),
                      Expanded(child: Stat(label: s.maxHr, value: i.maxHr == null ? '—' : f.int0(i.maxHr!), sub: s.bpm)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelTitle(s.hrZones),
                for (var z = 5; z >= 1; z--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text.rich(TextSpan(children: [
                                TextSpan(text: s.zone(z), style: WText.body),
                                TextSpan(
                                  text: '  ${s.zoneRange(ranges[z - 1].$1, ranges[z - 1].$2)}',
                                  style: WText.small,
                                ),
                              ])),
                            ),
                            Text(f.duration(i.zoneMinutes[z]), style: WText.body.copyWith(fontFeatures: WText.tabular)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ProportionBar(
                          fraction: zoneTotal <= 0 ? 0.0 : i.zoneMinutes[z] / zoneTotal,
                          color: WColors.zones[z],
                          height: 6,
                        ),
                      ],
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
                PanelTitle(s.activities),
                if (i.workouts.isEmpty) Text(s.noActivities, style: WText.bodyDim),
                for (final w in i.workouts) _WorkoutCard(w: w),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Stat(label: s.steps, value: i.steps == null ? '—' : f.thousands(i.steps!))),
                    Expanded(child: Stat(label: s.calories, value: i.activeKcal == null ? '—' : f.thousands(i.activeKcal!))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelTitle(s.last7),
                BarChart(
                  values: [for (final w in week) w?.strain],
                  colors: const [WColors.indigo],
                  labels: [for (var k = 6; k >= 0; k--) f.weekdayShort(addDays(day, -k))],
                  maxY: 21,
                  showValues: true,
                  format: (v) => v.toStringAsFixed(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(s.strainExplain, style: WText.small),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final WorkoutSummary w;
  const _WorkoutCard({required this.w});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final f = context.fmt;
    final ar = context.app.settings.isArabic;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(workoutIcon(w.type), color: WColors.indigo, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(workoutName(w.type, ar), style: WText.body.copyWith(fontWeight: FontWeight.w600))),
              Text(f.dec1(StrainModel.strainFromLoad(w.trimp)), style: WText.number.copyWith(color: WColors.indigo)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Stat(label: s.duration, value: f.duration(w.minutes))),
              Expanded(child: Stat(label: s.avgHr, value: w.avgHr == null ? '—' : f.int0(w.avgHr!))),
              Expanded(
                child: w.distanceM != null && w.distanceM! > 0
                    ? Stat(label: s.distance, value: '${f.dec1(w.distanceM! / 1000)} ${s.km}')
                    : Stat(label: s.calories, value: w.kcal == null ? '—' : f.int0(w.kcal!)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
