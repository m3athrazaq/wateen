import 'package:flutter/material.dart';

import '../engine/score.dart';
import '../models/raw.dart';
import '../util/dates.dart';
import '../util/stats.dart';
import 'ctx.dart';
import 'theme.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';
import 'widgets/ring.dart';
import '../util/clock.dart';

class SleepScreen extends StatelessWidget {
  final DateTime day;
  const SleepScreen({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final m = app.metricsFor(day);
    final sleep = m?.inputs.sleep;

    if (m == null || sleep == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.sleep)),
        body: EmptyNote(icon: Icons.bedtime_outlined, title: s.noSleepTitle, body: s.noSleepBody),
      );
    }

    final need = m.sleepNeed!;
    final latest = app.latest;
    final isLatest = latest != null && sameDay(latest.date, day);
    final week = [for (var i = 6; i >= 0; i--) app.metricsFor(addDays(day, -i))];

    Widget stageRow(String name, Color color, double minutes) {
      final pct = sleep.asleepMin > 0 ? minutes / sleep.asleepMin : 0.0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(child: Text(name, style: WText.body)),
                Text(f.duration(minutes), style: WText.body.copyWith(fontFeatures: WText.tabular)),
                SizedBox(width: 52, child: Text(f.pct(pct * 100), style: WText.label, textAlign: TextAlign.end)),
              ],
            ),
            const SizedBox(height: 6),
            ProportionBar(fraction: pct, color: color, height: 6),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.sleep)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: WovenRing(
              value: m.sleepScore == null ? null : m.sleepScore! / 100,
              color: WColors.lavender,
              size: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(m.sleepScore == null ? '—' : f.pct(m.sleepScore!), style: WText.hero.copyWith(fontSize: 46)),
                  Text(s.sleepPerformance, style: WText.label),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelTitle(s.hoursVsNeed),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(f.duration(sleep.asleepMin), style: WText.big),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(s.ofNeed(f.duration(need.totalMin)), style: WText.bodyDim),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ProportionBar(fraction: m.sleepPerformance ?? 0.0, color: WColors.lavender, height: 10),
                const SizedBox(height: 16),
                Text(s.needBreakdown, style: WText.label),
                const SizedBox(height: 4),
                InfoRow(label: s.needBase, value: f.duration(need.baseMin)),
                if (need.strainMin >= 1) InfoRow(label: s.needStrain, value: f.plus(f.duration(need.strainMin))),
                if (need.debtMin >= 1) InfoRow(label: s.needDebt, value: f.plus(f.duration(need.debtMin))),
                if (need.napMin >= 1) InfoRow(label: s.needNap, value: f.minus(f.duration(need.napMin))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelTitle(s.stages),
                Hypnogram(spans: sleep.spans, start: sleep.start, end: sleep.end, fmt: f),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(f.clock(sleep.start), style: WText.small),
                    Text(f.clock(sleep.end), style: WText.small),
                  ],
                ),
                const SizedBox(height: 12),
                if (sleep.hasStages) ...[
                  stageRow(s.stageAwake, WColors.stage(SleepStage.awake), sleep.awakeMin),
                  stageRow(s.stageLight, WColors.stage(SleepStage.light), sleep.lightMin),
                  stageRow(s.stageDeep, WColors.stage(SleepStage.deep), sleep.deepMin),
                  stageRow(s.stageRem, WColors.stage(SleepStage.rem), sleep.remMin),
                ] else
                  Text(s.stagesUnavailable, style: WText.bodyDim),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Stat(label: s.efficiency, value: f.pct(sleep.efficiency * 100))),
                    Expanded(
                      child: Stat(label: s.consistency, value: m.consistency == null ? '—' : f.pct(m.consistency! * 100)),
                    ),
                    Expanded(child: Stat(label: s.disturbances, value: '${sleep.disturbances}')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Stat(label: s.bedtime, value: f.clock(sleep.start))),
                    Expanded(child: Stat(label: s.wakeTime, value: f.clock(sleep.end))),
                    Expanded(child: Stat(label: s.timeInBed, value: f.duration(sleep.inBedMin))),
                  ],
                ),
                if (sleep.hasStages) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Stat(
                          label: s.restorative,
                          value: f.duration(sleep.restorativeMin),
                          sub: s.restorativeHint,
                        ),
                      ),
                      Expanded(
                        child: Stat(
                          label: s.respiratory,
                          value: m.inputs.respiratory == null ? '—' : f.dec1(m.inputs.respiratory!),
                          sub: s.rpm,
                        ),
                      ),
                      Expanded(child: Stat(label: s.debtNow, value: f.duration(m.debtAfterMin))),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelTitle(s.sleepSchedule),
                SleepWindowChart(
                  nights: [
                    for (final w in week)
                      w?.inputs.sleep == null ? null : (w!.inputs.sleep!.start, w.inputs.sleep!.end),
                  ],
                  labels: [for (var i = 6; i >= 0; i--) f.weekdayShort(addDays(day, -i))],
                  fmt: f,
                ),
              ],
            ),
          ),
          if (isLatest) ...[
            const SizedBox(height: 12),
            _CoachPanel(day: day),
          ],
        ],
      ),
    );
  }
}

class _CoachPanel extends StatelessWidget {
  final DateTime day;
  const _CoachPanel({required this.day});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final m = app.metricsFor(day)!;
    final need = SleepCoach.tonightNeed(app.settings, app.metrics, m);
    final eff = meanOf(app.lastDays(7).where((d) => d.inputs.sleep != null).map((d) => d.inputs.sleep!.efficiency)) ?? 0.9;
    final opts = SleepCoach.options(app.settings, need, clockNow(), efficiency: eff);
    final names = [s.coachPeak, s.coachPerform, s.coachGetBy];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(s.tonightTitle),
          Text(s.needTonight(f.duration(need.totalMin)), style: WText.bodyDim),
          const SizedBox(height: 8),
          for (var i = 0; i < opts.length; i++)
            InfoRow(label: '${names[i]} (${f.pct(opts[i].fraction * 100)})', value: f.clock(opts[i].bedtime)),
        ],
      ),
    );
  }
}
