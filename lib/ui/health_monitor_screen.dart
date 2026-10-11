import 'package:flutter/material.dart';

import 'ctx.dart';
import 'theme.dart';
import 'vitals.dart';
import 'widgets/common.dart';

class HealthMonitorScreen extends StatelessWidget {
  final DateTime? day;
  const HealthMonitorScreen({super.key, this.day});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final m = day == null ? app.latest : app.metricsFor(day!);
    if (m == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.healthMonitor)),
        body: EmptyNote(icon: Icons.monitor_heart_outlined, title: s.noDataTitle, body: s.noDataBody),
      );
    }
    final items = vitalsFor(m, s, f);
    final out = items.where((v) => v.ok == false).length;

    return Scaffold(
      appBar: AppBar(title: Text(s.healthMonitor)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Panel(
            child: Row(
              children: [
                Icon(out == 0 ? Icons.check_circle_outline : Icons.info_outline,
                    color: out == 0 ? WColors.palm : WColors.saffron, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(out == 0 ? s.allInRange : s.someOutOfRange(out), style: WText.title.copyWith(fontSize: 16)),
                      Text('${s.lastNight}${app.settings.isArabic ? '، ' : ', '}${f.dateShort(m.date)}', style: WText.small),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final v in items) ...[
            Panel(
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: WColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                    child: Icon(v.icon, color: WColors.ash, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.name, style: WText.body.copyWith(fontWeight: FontWeight.w600)),
                        Text(v.range ?? s.calibratingTitle, style: WText.small),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(text: v.value, style: WText.number),
                        TextSpan(text: ' ${v.unit}', style: WText.small),
                      ])),
                      const SizedBox(height: 4),
                      Dot(v.ok == null ? WColors.faint : (v.ok! ? WColors.palm : WColors.saffron)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          Text(s.notMedical, style: WText.small),
        ],
      ),
    );
  }
}
