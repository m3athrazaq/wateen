import 'package:flutter/material.dart';

import 'ctx.dart';
import 'labels.dart';
import 'theme.dart';
import 'widgets/common.dart';

class BodyAgeScreen extends StatelessWidget {
  const BodyAgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final r = app.bodyAge;

    return Scaffold(
      appBar: AppBar(title: Text(s.bodyAge)),
      body: r == null
          ? EmptyNote(icon: Icons.hourglass_empty, title: s.bodyAge, body: s.bodyAgeNeedData)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      Text(s.bodyAgeTitle, style: WText.label),
                      const SizedBox(height: 6),
                      Text(f.dec1(r.bodyAge), style: WText.hero.copyWith(fontSize: 64)),
                      Text(s.yourAge(r.chronologicalAge), style: WText.bodyDim),
                      const SizedBox(height: 6),
                      Builder(builder: (context) {
                        final d = r.bodyAge - r.chronologicalAge;
                        if (d.abs() < 0.3) return Text(s.sameAge, style: WText.title.copyWith(fontSize: 16));
                        return Text(
                          d < 0 ? s.younger(f.dec1(-d)) : s.older(f.dec1(d)),
                          style: WText.title.copyWith(fontSize: 16, color: d < 0 ? WColors.palm : WColors.saffron),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Panel(
                  child: Column(
                    children: [
                      for (final c in r.contributions)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ageFactorName(c.factor, s), style: WText.body),
                                    Text(ageFactorValue(c, s, f), style: WText.small),
                                  ],
                                ),
                              ),
                              Text(
                                s.yearsDelta(f.signed(c.years, digits: 1)),
                                style: WText.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: WText.tabular,
                                  color: c.years < 0 ? WColors.palm : (c.years > 0 ? WColors.saffron : WColors.ash),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(s.bodyAgeNote, style: WText.small),
              ],
            ),
    );
  }
}
