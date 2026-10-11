import 'package:flutter/material.dart';

import '../theme.dart';

/// A raised block of related content. Tappable blocks show a chevron.
class Panel extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;

  const Panel({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = WColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Title row for a panel, with an optional trailing widget.
class PanelTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final bool chevron;

  const PanelTitle(this.title, {super.key, this.trailing, this.chevron = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: WText.title.copyWith(fontSize: 16))),
          ?trailing,
          // chevron_right mirrors itself in right-to-left layouts.
          if (chevron) const Icon(Icons.chevron_right, color: WColors.faint, size: 22),
        ],
      ),
    );
  }
}

/// A labelled figure.
class Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? color;
  final CrossAxisAlignment align;

  const Stat({super.key, required this.label, required this.value, this.sub, this.color, this.align = CrossAxisAlignment.start});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: WText.label),
          const SizedBox(height: 4),
          Text(value, style: WText.number.copyWith(color: color ?? WColors.ivory)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!, style: WText.small),
          ],
        ],
      );
}

/// Small coloured status dot.
class Dot extends StatelessWidget {
  final Color color;
  final double size;
  const Dot(this.color, {super.key, this.size = 8});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// A row with a label at the start and a value at the end.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? leading;
  final Color? valueColor;

  const InfoRow({super.key, required this.label, required this.value, this.leading, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(child: Text(label, style: WText.body)),
            Text(value,
                style: WText.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? WColors.ivory,
                  fontFeatures: WText.tabular,
                )),
          ],
        ),
      );
}

/// Centered message for empty or not-yet-available content.
class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const EmptyNote({super.key, required this.icon, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: WColors.faint),
            const SizedBox(height: 16),
            Text(title, style: WText.title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, style: WText.bodyDim, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
        ),
      );
}

/// A legend chip: colour swatch and label.
class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const LegendItem(this.color, this.label, {super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(label, style: WText.small.copyWith(color: WColors.ash)),
        ],
      );
}

/// Horizontal proportion bar used for stages and zones.
class ProportionBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;
  const ProportionBar({super.key, required this.fraction, required this.color, this.height = 8});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Container(color: WColors.surfaceHigh),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
                child: Container(color: color),
              ),
            ],
          ),
        ),
      );
}

/// A bar centred on zero showing a signed effect (−3..+3).
class EffectBar extends StatelessWidget {
  final double effect;
  const EffectBar(this.effect, {super.key});

  @override
  Widget build(BuildContext context) {
    final v = (effect / 3).clamp(-1.0, 1.0).toDouble();
    final color = v >= 0 ? WColors.palm : WColors.madder;
    return SizedBox(
      height: 8,
      child: LayoutBuilder(builder: (context, c) {
        final half = c.maxWidth / 2;
        final w = half * v.abs();
        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: WColors.surfaceHigh, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            PositionedDirectional(
              start: v >= 0 ? half : half - w,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            PositionedDirectional(
              start: half - 0.5,
              top: -2,
              bottom: -2,
              width: 1,
              child: Container(color: WColors.ash),
            ),
          ],
        );
      }),
    );
  }
}
