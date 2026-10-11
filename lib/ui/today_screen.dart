import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/score.dart';
import '../engine/strain_model.dart';
import '../models/metrics.dart';
import '../util/dates.dart';
import '../util/stats.dart';
import 'ctx.dart';
import 'labels.dart';
import 'recovery_screen.dart';
import 'sleep_screen.dart';
import 'strain_screen.dart';
import 'stress_screen.dart';
import 'health_monitor_screen.dart';
import 'theme.dart';
import 'vitals.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';
import 'widgets/ring.dart';

class TodayScreen extends StatefulWidget {
  final VoidCallback onOpenJournal;
  const TodayScreen({super.key, required this.onOpenJournal});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DateTime? _day;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final now = DateTime.now();
    final today = dayOf(now);
    final latest = app.latest;
    final day = _day ?? latest?.date ?? today;
    final m = app.metricsFor(day);
    final first = app.metrics.isEmpty ? day : app.metrics.first.date;
    final isLatest = latest != null && sameDay(day, latest.date);

    String title;
    if (sameDay(day, today)) {
      title = s.today;
    } else if (sameDay(day, addDays(today, -1))) {
      title = s.yesterday;
    } else {
      title = f.dateShort(day);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: WColors.night,
          backgroundColor: WColors.ivory,
          onRefresh: () => app.refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: day.isAfter(first) ? () => setState(() => _day = addDays(day, -1)) : null,
                          icon: const Icon(Icons.chevron_left),
                          color: WColors.ivory,
                          disabledColor: WColors.line,
                        ),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: WText.title.copyWith(fontSize: 20),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(f.dateLong(day), style: WText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: day.isBefore(today) ? () => setState(() => _day = addDays(day, 1)) : null,
                          icon: const Icon(Icons.chevron_right),
                          color: WColors.ivory,
                          disabledColor: WColors.line,
                        ),
                      ],
                    ),
                  ),
                  if (app.isDemo)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: WColors.line),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(s.demoBadge, style: WText.small.copyWith(color: WColors.ash)),
                    ),
                  if (app.loading)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    IconButton(
                      tooltip: s.refresh,
                      onPressed: () => app.refresh(),
                      icon: const Icon(Icons.refresh, color: WColors.ash),
                    ),
                ],
              ),
              if (app.error != null && !app.loading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Text(s.syncError, style: WText.small.copyWith(color: WColors.madder)),
                ),
              if (m == null || !m.inputs.hasAnyData)
                app.loading
                    ? Padding(
                        padding: const EdgeInsets.only(top: 120),
                        child: Column(children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(s.syncing, style: WText.bodyDim),
                        ]),
                      )
                    : EmptyNote(icon: Icons.watch_outlined, title: s.noDataTitle, body: s.noDataBody)
              else ...[
                _Hero(m: m),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _SleepTile(m: m)),
                    const SizedBox(width: 12),
                    Expanded(child: _StrainTile(m: m)),
                  ],
                ),
                if (isLatest) ...[const SizedBox(height: 12), _TonightPanel(m: m)],
                if (m.inputs.stress != null) ...[const SizedBox(height: 12), _StressPanel(m: m)],
                const SizedBox(height: 12),
                _VitalsPanel(m: m),
                const SizedBox(height: 12),
                _ActivityPanel(m: m),
                if (isLatest && !app.journal.containsKey(dayKey(addDays(today, -1)))) ...[
                  const SizedBox(height: 12),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.journalPromptTitle, style: WText.title.copyWith(fontSize: 16)),
                        const SizedBox(height: 6),
                        Text(s.journalPromptBody, style: WText.bodyDim),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: widget.onOpenJournal, child: Text(s.openJournal)),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final DayMetrics m;
  const _Hero({required this.m});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final f = context.fmt;
    final rec = m.recovery;
    Widget center;
    String headline;
    String body;
    if (rec != null) {
      center = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$rec%', style: WText.hero),
          const SizedBox(height: 6),
          Text(s.recovery, style: WText.label),
        ],
      );
      final z = zoneOf(rec);
      headline = zoneTitle(z, s);
      final lo = f.int0(m.targetLo);
      final hi = f.int0(m.targetHi);
      body = switch (z) {
        RecoveryZone.green => s.guidanceGreen(lo, hi),
        RecoveryZone.yellow => s.guidanceYellow(lo, hi),
        RecoveryZone.red => s.guidanceRed(hi),
      };
    } else if (m.calibrating) {
      final have = math.max(m.hrvBase?.count ?? 0, m.rhrBase?.count ?? 0);
      center = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_top, color: WColors.ash, size: 30),
          const SizedBox(height: 8),
          Text(s.recovery, style: WText.label),
        ],
      );
      headline = s.calibratingTitle;
      body = s.calibratingBody(math.max(1, Scorer.minBaselineDays - have));
    } else {
      center = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('—', style: WText.hero.copyWith(color: WColors.faint)),
          const SizedBox(height: 6),
          Text(s.recovery, style: WText.label),
        ],
      );
      headline = s.noRecoveryTitle;
      body = s.noRecoveryBody;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.push(RecoveryScreen(day: m.date)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            WovenRing(
              value: rec == null ? null : rec / 100,
              color: WColors.recovery(rec),
              size: 236,
              child: center,
            ),
            const SizedBox(height: 18),
            Text(headline, style: WText.title.copyWith(fontSize: 20), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(body, style: WText.bodyDim, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepTile extends StatelessWidget {
  final DayMetrics m;
  const _SleepTile({required this.m});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final f = context.fmt;
    final sleep = m.inputs.sleep;
    return Panel(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(SleepScreen(day: m.date)),
      child: Row(
        children: [
          MiniRing(
            value: m.sleepScore == null ? null : m.sleepScore! / 100,
            color: WColors.lavender,
            text: m.sleepScore == null ? '—' : f.int0(m.sleepScore!),
            size: 58,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.sleep, style: WText.label),
                Text(sleep == null ? '—' : f.duration(sleep.asleepMin),
                    style: WText.title.copyWith(fontFeatures: WText.tabular)),
                if (m.sleepNeed != null)
                  Text(s.ofNeed(f.duration(m.sleepNeed!.totalMin)), style: WText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StrainTile extends StatelessWidget {
  final DayMetrics m;
  const _StrainTile({required this.m});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final f = context.fmt;
    return Panel(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(StrainScreen(day: m.date)),
      child: Row(
        children: [
          MiniRing(value: m.strain / 21, color: WColors.indigo, text: f.dec1(m.strain), size: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.strain, style: WText.label),
                Text(f.dec1(m.strain), style: WText.title.copyWith(fontFeatures: WText.tabular)),
                Text(s.targetRange(f.int0(m.targetLo), f.int0(m.targetHi)), style: WText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TonightPanel extends StatelessWidget {
  final DayMetrics m;
  const _TonightPanel({required this.m});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final need = SleepCoach.tonightNeed(app.settings, app.metrics, m);
    final eff = meanOf(app.lastDays(7).where((d) => d.inputs.sleep != null).map((d) => d.inputs.sleep!.efficiency)) ?? 0.9;
    final opts = SleepCoach.options(app.settings, need, DateTime.now(), efficiency: eff);
    final names = [s.coachPeak, s.coachPerform, s.coachGetBy];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(s.tonightTitle, trailing: const Icon(Icons.nightlight_round, color: WColors.lavender, size: 20)),
          Text(s.needTonight(f.duration(need.totalMin)), style: WText.bodyDim),
          const SizedBox(height: 10),
          for (var i = 0; i < opts.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 44, child: Text(f.pct(opts[i].fraction * 100), style: WText.label)),
                  Expanded(child: Text(names[i], style: WText.body)),
                  Text(f.clock(opts[i].bedtime),
                      style: WText.body.copyWith(
                        fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
                        fontFeatures: WText.tabular,
                      )),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(s.wakeAt(f.clockMinutes(app.settings.wakeTimeMin)), style: WText.small),
        ],
      ),
    );
  }
}

class _StressPanel extends StatelessWidget {
  final DayMetrics m;
  const _StressPanel({required this.m});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final f = context.fmt;
    final st = m.inputs.stress!;
    double? latest;
    for (final b in st.buckets.reversed) {
      if (b != null) {
        latest = b;
        break;
      }
    }
    return Panel(
      onTap: () => context.push(StressScreen(day: m.date)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(
            s.stress,
            chevron: true,
            trailing: latest == null
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('${s.stressNow}: ${stressLabel(latest, s)} (${f.dec1(latest)})',
                        style: WText.label.copyWith(color: WColors.stressLevel(latest))),
                  ),
          ),
          BarChart(
            values: st.buckets,
            colors: [for (final b in st.buckets) WColors.stressLevel(b)],
            maxY: 3,
            height: 64,
          ),
        ],
      ),
    );
  }
}

class _VitalsPanel extends StatelessWidget {
  final DayMetrics m;
  const _VitalsPanel({required this.m});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final f = context.fmt;
    final items = vitalsFor(m, s, f).take(4).toList();
    Widget cell(VitalItem v) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Dot(v.ok == null ? WColors.faint : (v.ok! ? WColors.palm : WColors.saffron)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.name, style: WText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: v.value, style: WText.number.copyWith(fontSize: 20)),
                    TextSpan(text: ' ${v.unit}', style: WText.small),
                  ])),
                ],
              ),
            ),
          ],
        );
    return Panel(
      onTap: () => context.push(HealthMonitorScreen(day: m.date)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(s.vitals, chevron: true),
          Row(children: [Expanded(child: cell(items[0])), Expanded(child: cell(items[1]))]),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: cell(items[2])), Expanded(child: cell(items[3]))]),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  final DayMetrics m;
  const _ActivityPanel({required this.m});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final f = context.fmt;
    final ar = context.app.settings.isArabic;
    final w = m.inputs.workouts;
    return Panel(
      onTap: () => context.push(StrainScreen(day: m.date)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(s.activities, chevron: true),
          if (w.isEmpty) Text(s.noActivities, style: WText.bodyDim),
          for (final x in w)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: WColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                    child: Icon(workoutIcon(x.type), color: WColors.indigo, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(workoutName(x.type, ar), style: WText.body.copyWith(fontWeight: FontWeight.w600)),
                        Text('${f.clock(x.start)}${ar ? '، ' : ', '}${f.duration(x.minutes)}', style: WText.small),
                      ],
                    ),
                  ),
                  Text(f.dec1(StrainModel.strainFromLoad(x.trimp)),
                      style: WText.number.copyWith(fontSize: 18, color: WColors.indigo)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Stat(label: s.steps, value: m.inputs.steps == null ? '—' : f.thousands(m.inputs.steps!))),
              Expanded(
                child: Stat(
                    label: s.calories, value: m.inputs.activeKcal == null ? '—' : f.thousands(m.inputs.activeKcal!)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
