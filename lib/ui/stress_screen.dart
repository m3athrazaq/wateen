import 'package:flutter/material.dart';

import 'ctx.dart';
import 'labels.dart';
import 'theme.dart';
import 'widgets/charts.dart';
import 'widgets/common.dart';

class StressScreen extends StatelessWidget {
  final DateTime day;
  const StressScreen({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final m = app.metricsFor(day);
    final st = m?.inputs.stress;

    if (m == null || st == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.stress)),
        body: EmptyNote(icon: Icons.self_improvement, title: s.stress, body: s.noStress),
      );
    }

    final total = st.totalMin <= 0 ? 1.0 : st.totalMin;
    final start = st.bucketStart ?? m.inputs.windowStart;
    final labels = <String>[
      for (var k = 0; k < st.buckets.length; k++)
        k % 4 == 0 ? f.clock(start.add(Duration(minutes: 30 * k))).split(' ').first : '',
    ];

    Widget level(String name, Color color, double minutes) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            children: [
              Row(
                children: [
                  Dot(color, size: 10),
                  const SizedBox(width: 8),
                  Expanded(child: Text(name, style: WText.body)),
                  Text(f.duration(minutes), style: WText.body.copyWith(fontFeatures: WText.tabular)),
                ],
              ),
              const SizedBox(height: 6),
              ProportionBar(fraction: minutes / total, color: color, height: 6),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.stress)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                Text(st.score == null ? '—' : f.dec1(st.score!),
                    style: WText.hero.copyWith(color: WColors.stressLevel(st.score))),
                const SizedBox(height: 4),
                Text(st.score == null ? s.noStress : stressLabel(st.score!, s), style: WText.title),
                Text(f.dateLong(day), style: WText.small),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelTitle(s.stressTimeline),
                BarChart(
                  values: st.buckets,
                  colors: [for (final b in st.buckets) WColors.stressLevel(b)],
                  labels: labels,
                  maxY: 3,
                  height: 140,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelTitle(s.stressTime),
                level(s.stressLow, WColors.calm, st.lowMin),
                level(s.stressMed, WColors.saffron, st.medMin),
                level(s.stressHigh, WColors.stress, st.highMin),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(s.stressExplain, style: WText.bodyDim),
          const SizedBox(height: 10),
          Text(s.stressTip, style: WText.bodyDim),
        ],
      ),
    );
  }
}
