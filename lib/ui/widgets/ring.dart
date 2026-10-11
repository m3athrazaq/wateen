import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The signature gauge: a ring of Sadu-style triangular teeth that fill
/// clockwise from the top. An optional band marks a target range.
class WovenRing extends StatelessWidget {
  final double? value;
  final Color color;
  final double size;
  final int teeth;
  final double? bandFrom;
  final double? bandTo;
  final Widget? child;
  final bool animate;

  const WovenRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 220,
    this.teeth = 60,
    this.bandFrom,
    this.bandTo,
    this.child,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final target = (value ?? 0).clamp(0.0, 1.0).toDouble();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    Widget ring(double v) => CustomPaint(
          size: Size.square(size),
          painter: _WovenPainter(
            value: v,
            color: color,
            teeth: teeth,
            empty: value == null,
            bandFrom: bandFrom,
            bandTo: bandTo,
          ),
          child: SizedBox.square(dimension: size, child: Center(child: child)),
        );
    if (!animate || reduceMotion) return ring(target);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ring(v),
    );
  }
}

class _WovenPainter extends CustomPainter {
  final double value;
  final Color color;
  final int teeth;
  final bool empty;
  final double? bandFrom;
  final double? bandTo;

  _WovenPainter({
    required this.value,
    required this.color,
    required this.teeth,
    required this.empty,
    this.bandFrom,
    this.bandTo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rOuter = size.width / 2 - (bandFrom != null ? 8 : 2);
    final depth = size.width * 0.085;
    final rInner = rOuter - depth;
    final step = 2 * math.pi / teeth;
    final half = step * 0.36;
    final lit = (value * teeth).floor();
    final partial = value * teeth - lit;

    final off = Paint()..color = WColors.line;
    final on = Paint()..color = color;

    for (var i = 0; i < teeth; i++) {
      final a = -math.pi / 2 + i * step + step / 2;
      final path = Path()
        ..moveTo(c.dx + rInner * math.cos(a - half), c.dy + rInner * math.sin(a - half))
        ..lineTo(c.dx + rOuter * math.cos(a), c.dy + rOuter * math.sin(a))
        ..lineTo(c.dx + rInner * math.cos(a + half), c.dy + rInner * math.sin(a + half))
        ..close();
      if (empty) {
        canvas.drawPath(path, off);
      } else if (i < lit) {
        canvas.drawPath(path, on);
      } else if (i == lit && partial > 0.05) {
        canvas.drawPath(path, Paint()..color = Color.lerp(WColors.line, color, partial)!);
      } else {
        canvas.drawPath(path, off);
      }
    }

    // Inner thread.
    canvas.drawCircle(
      c,
      rInner - depth * 0.45,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = WColors.line,
    );

    if (bandFrom != null && bandTo != null) {
      final from = bandFrom!.clamp(0.0, 1.0).toDouble();
      final to = bandTo!.clamp(0.0, 1.0).toDouble();
      final rect = Rect.fromCircle(center: c, radius: rOuter + 5);
      canvas.drawArc(
        rect,
        -math.pi / 2 + 2 * math.pi * from,
        2 * math.pi * (to - from),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = WColors.ivory.withValues(alpha: 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WovenPainter old) =>
      old.value != value || old.color != color || old.empty != empty || old.bandFrom != bandFrom || old.bandTo != bandTo;
}

/// A compact ring for tiles.
class MiniRing extends StatelessWidget {
  final double? value;
  final Color color;
  final String text;
  final double size;

  const MiniRing({super.key, required this.value, required this.color, required this.text, this.size = 64});

  @override
  Widget build(BuildContext context) => WovenRing(
        value: value,
        color: color,
        size: size,
        teeth: 28,
        animate: false,
        child: Text(text, style: WText.title.copyWith(fontSize: size * 0.24, fontFeatures: WText.tabular)),
      );
}
