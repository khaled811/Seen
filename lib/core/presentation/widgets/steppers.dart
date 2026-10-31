// StatusStepper — vertical step progression, domain-agnostic (title/meta
// strings only), reusable across any multi-stage flow (request timeline,
// booking flow, ticket lifecycle, …).
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import 'svg_icon.dart';

class SeenStep {
  const SeenStep({required this.title, this.meta});

  final String title;

  /// Timestamp, or the expected time for the current step.
  final String? meta;
}

/// Vertical status progression (Figma "Stepper"). Done = violet dot with a
/// check and a violet-40 connector; current = violet-10 dot with a violet ring
/// and core, title in Medium, meta in violet; upcoming = hollow strong-line
/// ring with muted text. A [current] equal to `steps.length` marks every step
/// as done.
class SeenStatusStepper extends StatelessWidget {
  const SeenStatusStepper({super.key, required this.steps, required this.current});

  final List<SeenStep> steps;

  /// 0-based index of the current step.
  final int current;

  static const _dot = 26.0;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _dot,
                  child: Column(children: [
                    _marker(c, i),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(minHeight: 30),
                          decoration: BoxDecoration(
                            color: i < current ? SeenBrand.violet40 : c.border,
                            borderRadius: const BorderRadius.all(Radius.circular(1)),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(width: SeenSpace.s3),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 2, bottom: i < steps.length - 1 ? SeenSpace.s3 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: (i == current ? type.bodyStrong : type.body)
                              .copyWith(color: i > current ? c.inkMuted : c.ink),
                        ),
                        if (steps[i].meta != null)
                          Text(
                            steps[i].meta!,
                            style: type.caption.copyWith(
                              color: i == current ? c.primary : c.inkMuted,
                              fontFeatures: SeenFonts.tabular,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _marker(SeenColors c, int i) {
    if (i < current) {
      return Container(
        width: _dot,
        height: _dot,
        decoration: const BoxDecoration(color: SeenBrand.violet, shape: BoxShape.circle),
        child: SeenCheckGlyph(size: 14, color: c.onPrimary),
      );
    }
    if (i == current) {
      return Container(
        width: _dot,
        height: _dot,
        decoration: BoxDecoration(
          color: c.primarySoft,
          shape: BoxShape.circle,
          border: Border.all(color: SeenBrand.violet, width: 2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: SeenBrand.violet, shape: BoxShape.circle),
          ),
        ),
      );
    }
    return Container(
      width: _dot,
      height: _dot,
      decoration: BoxDecoration(
        color: c.card,
        shape: BoxShape.circle,
        border: Border.all(color: c.borderStrong, width: 1.5),
      ),
    );
  }
}
