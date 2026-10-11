import 'package:flutter/material.dart';

import '../models/metrics.dart';
import '../util/dates.dart';
import 'ctx.dart';
import 'labels.dart';
import 'theme.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';
import 'widgets/ring.dart';

class RecoveryScreen extends StatelessWidget {
  final DateTime day;
  const RecoveryScreen({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final m = app.metricsFor(day);
    final week = [for (var i = 6; i >= 0; i--) app.metricsFor(addDays(day, -i))];

    return Scaffold(
      appBar: AppBar(title: Text(s.recovery)),
      body: m == null
          ? EmptyNote(icon: Icons.favorite_border, title: s.noDataTitle, body: s.noDataBody)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Center(
                  child: WovenRing(
                    value: m.recovery == null ? null : m.recovery! / 100,
                    color: WColors.recovery(m.recovery),
                    size: 200,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m.recovery == null ? '—' : '${m.recovery}%', style: WText.hero.copyWith(fontSize: 48)),
                        Text(f.dateShort(day), style: WText.small),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (m.zone != null)
                  Text(zoneTitle(m.zone!, s), style: WText.title, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(s.recoveryExplain, style: WText.bodyDim, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PanelTitle(s.contributors),
                      if (m.contributors.isEmpty)
                        Text(m.calibrating ? s.calibratingTitle : s.noRecoveryBody, style: WText.bodyDim),
                      for (final c in m.contributors) _ContributorRow(c: c),
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
                        values: [for (final w in week) w?.recovery?.toDouble()],
                        colors: [for (final w in week) WColors.recovery(w?.recovery)],
                        labels: [for (var i = 6; i >= 0; i--) f.weekdayShort(addDays(day, -i))],
                        maxY: 100,
                        showValues: true,
                        height: 150,
                      ),
                    ],
                  ),
                ),
                if (app.isIOS) ...[
                  const SizedBox(height: 16),
                  Text(s.hrvNoteIos, style: WText.small),
                ],
              ],
            ),
    );
  }
}

class _ContributorRow extends StatelessWidget {
  final Contributor c;
  const _ContributorRow({required this.c});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final f = context.fmt;
    final verdict = c.effect > 0.35 ? s.helps : (c.effect < -0.35 ? s.hurts : s.neutral);
    final verdictColor = c.effect > 0.35 ? WColors.palm : (c.effect < -0.35 ? WColors.madder : WColors.ash);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(contributorName(c.kind, s), style: WText.body.copyWith(fontWeight: FontWeight.w600))),
              Text(contributorValue(c.kind, c.value, s, f), style: WText.body.copyWith(fontFeatures: WText.tabular)),
            ],
          ),
          const SizedBox(height: 8),
          EffectBar(c.effect),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  c.baseline == null ? '' : s.yourAverage(contributorValue(c.kind, c.baseline, s, f)),
                  style: WText.small,
                ),
              ),
              Text(verdict, style: WText.small.copyWith(color: verdictColor)),
            ],
          ),
        ],
      ),
    );
  }
}
