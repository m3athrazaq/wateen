import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/day.dart';
import '../../models/raw.dart';
import '../format.dart';
import '../theme.dart';

bool _rtl(BuildContext c) => Directionality.of(c) == TextDirection.rtl;

void _text(Canvas canvas, String s, Offset at, TextStyle style, {TextAlign align = TextAlign.center, double width = 40}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout(minWidth: width, maxWidth: width);
  tp.paint(canvas, Offset(at.dx - width / 2, at.dy));
}

const _axis = TextStyle(fontFamily: 'Plex', fontSize: 10.5, color: WColors.faint);

/// Vertical bars, oldest first. In right-to-left layouts time runs from
/// right to left.
class BarChart extends StatelessWidget {
  final List<double?> values;
  final List<Color> colors;
  final List<String>? labels;
  final double? maxY;
  final double height;
  final bool showValues;
  final String Function(double)? format;
  final double? reference;

  const BarChart({
    super.key,
    required this.values,
    required this.colors,
    this.labels,
    this.maxY,
    this.height = 150,
    this.showValues = false,
    this.format,
    this.reference,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _BarPainter(this, _rtl(context)),
        ),
      );
}

class _BarPainter extends CustomPainter {
  final BarChart c;
  final bool rtl;
  _BarPainter(this.c, this.rtl);

  @override
  void paint(Canvas canvas, Size size) {
    final n = c.values.length;
    if (n == 0) return;
    final labelH = c.labels == null ? 0.0 : 18.0;
    final topPad = c.showValues ? 16.0 : 4.0;
    final chartH = size.height - labelH - topPad;
    final maxV = c.maxY ??
        math.max(1.0, c.values.whereType<double>().fold<double>(0, (a, b) => math.max(a, b)) * 1.1);
    final slot = size.width / n;
    final barW = math.min(26.0, slot * 0.62);
    final labelEvery = (n / 10).ceil();

    for (var i = 0; i < n; i++) {
      final pos = rtl ? n - 1 - i : i;
      final cx = slot * pos + slot / 2;
      final v = c.values[i];
      if (v == null) {
        canvas.drawCircle(Offset(cx, topPad + chartH - 2), 2, Paint()..color = WColors.line);
      } else {
        final h = math.max(2.0, chartH * (v / maxV).clamp(0.0, 1.0));
        final r = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, topPad + chartH - h, barW, h),
          topLeft: Radius.circular(math.min(6.0, barW / 2)),
          topRight: Radius.circular(math.min(6.0, barW / 2)),
        );
        canvas.drawRRect(r, Paint()..color = c.colors[i % c.colors.length]);
        if (c.showValues) {
          _text(canvas, c.format?.call(v) ?? v.round().toString(), Offset(cx, topPad + chartH - h - 15),
              const TextStyle(fontFamily: 'Plex', fontSize: 11, color: WColors.ash),
              width: slot);
        }
      }
      if (c.labels != null && i % labelEvery == 0 && i < c.labels!.length) {
        _text(canvas, c.labels![i], Offset(cx, size.height - labelH + 4), _axis, width: math.max(slot * labelEvery, 24.0));
      }
    }

    if (c.reference != null) {
      final y = topPad + chartH - chartH * (c.reference! / maxV).clamp(0.0, 1.0);
      final p = Paint()
        ..color = WColors.ivory.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => true;
}

/// A line over days with an optional shaded personal range.
class LineChart extends StatelessWidget {
  final List<double?> values;
  final Color color;
  final List<String>? labels;
  final double? bandLo;
  final double? bandHi;
  final double height;

  const LineChart({
    super.key,
    required this.values,
    required this.color,
    this.labels,
    this.bandLo,
    this.bandHi,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _LinePainter(this, _rtl(context))),
      );
}

class _LinePainter extends CustomPainter {
  final LineChart c;
  final bool rtl;
  _LinePainter(this.c, this.rtl);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = c.values.whereType<double>().toList();
    if (pts.isEmpty) return;
    final labelH = c.labels == null ? 0.0 : 18.0;
    final chartH = size.height - labelH - 8;
    var lo = pts.reduce(math.min);
    var hi = pts.reduce(math.max);
    if (c.bandLo != null) lo = math.min(lo, c.bandLo!);
    if (c.bandHi != null) hi = math.max(hi, c.bandHi!);
    final pad = math.max((hi - lo) * 0.15, 1.0);
    lo -= pad;
    hi += pad;
    final n = c.values.length;
    final slot = size.width / n;
    double x(int i) => slot * (rtl ? n - 1 - i : i) + slot / 2;
    double y(double v) => 4.0 + chartH * (1 - (v - lo) / (hi - lo));

    if (c.bandLo != null && c.bandHi != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(0, y(c.bandHi!), size.width, y(c.bandLo!)),
          const Radius.circular(6),
        ),
        Paint()..color = c.color.withValues(alpha: 0.10),
      );
    }

    final line = Paint()
      ..color = c.color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Path? path;
    for (var i = 0; i < n; i++) {
      final v = c.values[i];
      if (v == null) {
        if (path != null) canvas.drawPath(path, line);
        path = null;
        continue;
      }
      final p = Offset(x(i), y(v));
      if (path == null) {
        path = Path()..moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      if (n <= 31) canvas.drawCircle(p, 2.6, Paint()..color = c.color);
    }
    if (path != null) canvas.drawPath(path, line);

    if (c.labels != null) {
      final every = (n / 10).ceil();
      for (var i = 0; i < n && i < c.labels!.length; i += every) {
        _text(canvas, c.labels![i], Offset(x(i), size.height - labelH + 4), _axis, width: math.max(slot * every, 24.0));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}

/// Sleep stages over the night, one lane per stage.
class Hypnogram extends StatelessWidget {
  final List<StageSpan> spans;
  final DateTime start;
  final DateTime end;
  final Fmt fmt;
  final double height;

  const Hypnogram({super.key, required this.spans, required this.start, required this.end, required this.fmt, this.height = 150});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _HypnoPainter(this, _rtl(context))),
      );
}

class _HypnoPainter extends CustomPainter {
  final Hypnogram h;
  final bool rtl;
  _HypnoPainter(this.h, this.rtl);

  static int lane(SleepStage s) => switch (s) {
        SleepStage.awake || SleepStage.outOfBed => 0,
        SleepStage.rem => 1,
        SleepStage.light || SleepStage.asleep || SleepStage.session || SleepStage.inBed => 2,
        SleepStage.deep => 3,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final total = h.end.difference(h.start).inSeconds.toDouble();
    if (total <= 0) return;
    const labelH = 18.0;
    final laneH = (size.height - labelH) / 4;
    double x(DateTime t) {
      final f = (t.difference(h.start).inSeconds / total).clamp(0.0, 1.0);
      return rtl ? size.width * (1 - f) : size.width * f;
    }

    final grid = Paint()..color = WColors.line;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, laneH * i), Offset(size.width, laneH * i), grid);
    }
    for (final s in h.spans) {
      final x1 = x(s.start);
      final x2 = x(s.end);
      final l = lane(s.stage);
      final rect = Rect.fromLTRB(math.min(x1, x2), laneH * l + 3, math.max(math.max(x1, x2), math.min(x1, x2) + 1.5),
          laneH * (l + 1) - 3);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), Paint()..color = WColors.stage(s.stage));
    }
    // Hour ticks.
    var t = DateTime(h.start.year, h.start.month, h.start.day, h.start.hour + 1);
    var k = 0;
    while (t.isBefore(h.end)) {
      if (k % 2 == 0) {
        _text(canvas, h.fmt.clock(t).split(' ').first, Offset(x(t), size.height - labelH + 4), _axis, width: 40);
      }
      t = t.add(const Duration(hours: 1));
      k++;
    }
  }

  @override
  bool shouldRepaint(covariant _HypnoPainter old) => true;
}

/// Heart rate through the day, coloured by zone.
class HeartRateChart extends StatelessWidget {
  final List<HrPoint> points;
  final DateTime start;
  final DateTime end;
  final double maxHr;
  final Fmt fmt;
  final double height;

  const HeartRateChart({
    super.key,
    required this.points,
    required this.start,
    required this.end,
    required this.maxHr,
    required this.fmt,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _HrPainter(this, _rtl(context))),
      );
}

class _HrPainter extends CustomPainter {
  final HeartRateChart c;
  final bool rtl;
  _HrPainter(this.c, this.rtl);

  @override
  void paint(Canvas canvas, Size size) {
    if (c.points.isEmpty) return;
    final total = c.end.difference(c.start).inSeconds.toDouble();
    if (total <= 0) return;
    const labelH = 18.0;
    final chartH = size.height - labelH - 6;
    const lo = 40.0;
    final hi = math.max(c.maxHr, c.points.map((p) => p.bpm).reduce(math.max) + 5);
    double x(DateTime t) {
      final f = (t.difference(c.start).inSeconds / total).clamp(0.0, 1.0);
      return rtl ? size.width * (1 - f) : size.width * f;
    }

    double y(double v) => 4.0 + chartH * (1 - ((v - lo) / (hi - lo)).clamp(0.0, 1.0));

    for (final pct in const [0.5, 0.7, 0.9]) {
      final yy = y(c.maxHr * pct);
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), Paint()..color = WColors.line);
    }
    for (var i = 1; i < c.points.length; i++) {
      final a = c.points[i - 1];
      final b = c.points[i];
      if (b.time.difference(a.time) > const Duration(minutes: 20)) continue;
      final zone = _zone(math.max(a.bpm, b.bpm));
      canvas.drawLine(
        Offset(x(a.time), y(a.bpm)),
        Offset(x(b.time), y(b.bpm)),
        Paint()
          ..color = WColors.zones[zone]
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    var t = DateTime(c.start.year, c.start.month, c.start.day, c.start.hour + 1);
    final span = c.end.difference(c.start).inHours;
    final every = span > 12 ? 4 : 2;
    while (t.isBefore(c.end)) {
      if (t.hour % every == 0) {
        _text(canvas, c.fmt.clock(t).split(':').first + (c.fmt.ar ? (t.hour < 12 ? 'ص' : 'م') : (t.hour < 12 ? 'a' : 'p')),
            Offset(x(t), size.height - labelH + 4), _axis,
            width: 36);
      }
      t = t.add(const Duration(hours: 1));
    }
  }

  int _zone(double bpm) {
    final p = bpm / c.maxHr;
    if (p < 0.5) return 0;
    if (p < 0.6) return 1;
    if (p < 0.7) return 2;
    if (p < 0.8) return 3;
    if (p < 0.9) return 4;
    return 5;
  }

  @override
  bool shouldRepaint(covariant _HrPainter old) => true;
}

/// Bedtime-to-wake bars for recent nights on a 20:00–12:00 axis.
class SleepWindowChart extends StatelessWidget {
  final List<(DateTime, DateTime)?> nights;
  final List<String> labels;
  final Fmt fmt;
  final double height;

  const SleepWindowChart({super.key, required this.nights, required this.labels, required this.fmt, this.height = 170});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _WindowPainter(this, _rtl(context))),
      );
}

class _WindowPainter extends CustomPainter {
  final SleepWindowChart c;
  final bool rtl;
  _WindowPainter(this.c, this.rtl);

  /// Minutes after 20:00.
  static double _m(DateTime t) {
    final m = (t.hour * 60 + t.minute).toDouble();
    return m >= 20 * 60 ? m - 20 * 60 : m + 4 * 60;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = c.nights.length;
    if (n == 0) return;
    const labelH = 18.0;
    const axisW = 44.0;
    final chartH = size.height - labelH - 6;
    const span = 960.0;
    final plotW = size.width - axisW;
    final slot = plotW / n;
    final barW = math.min(18.0, slot * 0.5);
    double y(double m) => 4.0 + chartH * (m / span).clamp(0.0, 1.0);
    final axisX = rtl ? size.width - axisW / 2 : axisW / 2;
    for (final h in const [22, 2, 6, 10]) {
      final m = (h >= 20 ? (h - 20) * 60 : (h + 4) * 60).toDouble();
      final yy = y(m);
      final x0 = rtl ? 0.0 : axisW;
      final x1 = rtl ? plotW : size.width;
      canvas.drawLine(Offset(x0, yy), Offset(x1, yy), Paint()..color = WColors.line);
      _text(canvas, c.fmt.clockMinutes(h * 60).replaceAll(':00', ''), Offset(axisX, yy - 7), _axis, width: axisW);
    }
    for (var i = 0; i < n; i++) {
      final pos = rtl ? n - 1 - i : i;
      final cx = (rtl ? 0.0 : axisW) + slot * pos + slot / 2;
      final w = c.nights[i];
      if (w != null) {
        final top = y(_m(w.$1));
        var bottom = y(_m(w.$2));
        if (bottom < top) bottom = y(span);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(cx - barW / 2, top, cx + barW / 2, bottom), Radius.circular(barW / 2)),
          Paint()..color = WColors.lavender,
        );
      }
      if (i < c.labels.length) {
        _text(canvas, c.labels[i], Offset(cx, size.height - labelH + 4), _axis, width: slot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WindowPainter old) => true;
}
