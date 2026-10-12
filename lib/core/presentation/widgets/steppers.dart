// StatusStepper — vertical step progression, domain-agnostic (title/meta
// strings only), reusable across any multi-stage flow (request timeline,
// booking flow, ticket lifecycle, …).
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';

class SeenStep {
  const SeenStep({required this.title, this.meta});

  final String title;

  /// Timestamp, or the expected time for the current step.
  final String? meta;
}

/// Vertical status progression. Done = sage dot + check + green connector;
/// current = accentInk ring + label; upcoming = borderStrong ring, muted label.
class SeenStatusStepper extends StatelessWidget {
  const SeenStatusStepper({super.key, required this.steps, required this.current});

  final List<SeenStep> steps;

  /// 0-based index of the current step.
  final int current;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(children: [
                    _dot(c, i),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.only(top: 2, bottom: 2),
                          color: i < current ? c.successFg : c.border,
                        ),
                      ),
                  ]),
                ),
                const SizedBox(width: SeenSpace.s3),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < steps.length - 1 ? SeenSpace.s5 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: text.bodyMedium!.copyWith(
                            color: i == current ? c.accentInk : (i > current ? c.inkMuted : c.ink),
                            fontWeight: i == current ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        if (steps[i].meta != null)
                          Text(steps[i].meta!, style: text.labelSmall!.copyWith(fontFeatures: SeenFonts.tabular)),
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

  Widget _dot(SeenColors c, int i) {
    if (i < current) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: c.successFg, shape: BoxShape.circle),
        child: Icon(SeenIcons.check, size: 14, color: c.card),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: c.card,
        shape: BoxShape.circle,
        border: Border.all(color: i == current ? c.accentInk : c.borderStrong, width: i == current ? 7 : 2),
      ),
    );
  }
}
