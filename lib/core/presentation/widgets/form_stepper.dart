// FormStepper — Figma "Form stepper": a horizontal progress card with numbered
// steps joined by connectors. Done = violet dot + check, current = white dot
// with a violet ring and number, upcoming = strong-line ring.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_strings.dart';
import 'svg_icon.dart';

class SeenFormStepper extends StatelessWidget {
  const SeenFormStepper({super.key, required this.labels, required this.current});

  /// Step names, first to last.
  final List<String> labels;

  /// 0-based index of the current step; earlier ones are done.
  final int current;

  static const _dot = 28.0;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final s = SeenStrings.of(context);

    Widget marker(int i) {
      if (i < current) {
        return DecoratedBox(
          decoration: const BoxDecoration(gradient: SeenBrand.gradientCta, shape: BoxShape.circle),
          child: SizedBox(width: _dot, height: _dot, child: SeenCheckGlyph(size: 14, color: c.onPrimary)),
        );
      }
      final isCurrent = i == current;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          shape: BoxShape.circle,
          border: Border.all(color: isCurrent ? SeenBrand.violet : c.borderStrong, width: isCurrent ? 2 : 1.5),
        ),
        child: SizedBox(
          width: _dot,
          height: _dot,
          child: Center(
            child: Text(s.numeral(i + 1), style: type.label.copyWith(color: isCurrent ? SeenBrand.violet : c.inkMuted)),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: '${s.stepOf(current + 1, labels.length)}: ${labels[current.clamp(0, labels.length - 1)]}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: SeenBrand.gradientPromo,
          borderRadius: const BorderRadius.all(SeenRadius.r22),
          border: Border.all(color: c.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(SeenSpace.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: _dot / 2 - 1, left: SeenSpace.s2, right: SeenSpace.s2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: i <= current ? SeenBrand.violet40 : c.borderStrong,
                          borderRadius: const BorderRadius.all(Radius.circular(1)),
                        ),
                        child: const SizedBox(height: 2),
                      ),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    marker(i),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: type.caption.copyWith(color: i <= current ? c.ink : c.inkMuted),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
