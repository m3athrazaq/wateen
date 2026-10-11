import 'dart:math' as math;

import 'package:flutter/material.dart' hide Baseline;

import '../l10n/strings.dart';
import '../models/metrics.dart';
import '../util/stats.dart';
import 'format.dart';

class VitalItem {
  final String name;
  final String value;
  final String unit;
  final String? range;

  /// True when inside the personal range, false when outside, null when unknown.
  final bool? ok;
  final IconData icon;

  const VitalItem({
    required this.name,
    required this.value,
    required this.unit,
    this.range,
    this.ok,
    required this.icon,
  });
}

bool? _within(double? v, Baseline? b, double sdFloor) {
  if (v == null || b == null || b.count < 4) return null;
  return (v - b.mean).abs() <= 2 * math.max(b.sd, sdFloor);
}

/// Overnight vitals with their personal usual ranges (mean ± 2 SD).
List<VitalItem> vitalsFor(DayMetrics m, S s, Fmt f) {
  final i = m.inputs;
  final out = <VitalItem>[];

  final hb = m.hrvBase;
  out.add(VitalItem(
    name: s.hrv,
    value: i.hrv == null ? '—' : f.int0(i.hrv!),
    unit: s.ms,
    icon: Icons.graphic_eq,
    ok: i.hrv == null || i.hrv! <= 0 ? null : _within(math.log(i.hrv!), hb, 0.07),
    range: hb == null || hb.count < 4
        ? null
        : s.usualRange(f.int0(math.exp(hb.mean - 2 * math.max(hb.sd, 0.07))),
            f.int0(math.exp(hb.mean + 2 * math.max(hb.sd, 0.07)))),
  ));

  final rb = m.rhrBase;
  out.add(VitalItem(
    name: s.rhr,
    value: i.rhr == null ? '—' : f.int0(i.rhr!),
    unit: s.bpm,
    icon: Icons.favorite_border,
    ok: _within(i.rhr, rb, 1.5),
    range: rb == null || rb.count < 4
        ? null
        : s.usualRange(f.int0(rb.mean - 2 * math.max(rb.sd, 1.5)), f.int0(rb.mean + 2 * math.max(rb.sd, 1.5))),
  ));

  final rr = m.rrBase;
  out.add(VitalItem(
    name: s.respiratory,
    value: i.respiratory == null ? '—' : f.dec1(i.respiratory!),
    unit: s.rpm,
    icon: Icons.air,
    ok: _within(i.respiratory, rr, 0.35),
    range: rr == null || rr.count < 4
        ? null
        : s.usualRange(f.dec1(rr.mean - 2 * math.max(rr.sd, 0.35)), f.dec1(rr.mean + 2 * math.max(rr.sd, 0.35))),
  ));

  out.add(VitalItem(
    name: s.spo2,
    value: i.spo2 == null ? '—' : f.int0(i.spo2!),
    unit: '%',
    icon: Icons.water_drop_outlined,
    ok: i.spo2 == null ? null : i.spo2! >= 95,
    range: s.usualRange('95', '100'),
  ));

  final tb = m.tempBase;
  final dev = (i.temperature != null && tb != null) ? i.temperature! - tb.mean : null;
  out.add(VitalItem(
    name: s.temperature,
    value: dev == null ? (i.temperature == null ? '—' : f.dec1(i.temperature!)) : f.signed(dev, digits: 1),
    unit: '°',
    icon: Icons.thermostat,
    ok: _within(i.temperature, tb, 0.15),
    range: tb == null || tb.count < 4
        ? null
        : s.usualRange(f.signed(-2 * math.max(tb.sd, 0.15), digits: 1), f.signed(2 * math.max(tb.sd, 0.15), digits: 1)),
  ));
  return out;
}
