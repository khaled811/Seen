// Tag — generic 20px pill label, reusable across sub-agent rows, chips, etc.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';

/// 20px tag, radius-xs: primarySoft/primaryInk, or muted (surfaceSunken/inkSecondary).
class SeenTag extends StatelessWidget {
  const SeenTag(this.label, {super.key, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: muted ? c.surfaceSunken : c.primarySoft,
        borderRadius: const BorderRadius.all(SeenRadius.xs),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(label,
            maxLines: 1,
            style: seenStyle(11, 16, FontWeight.w600, muted ? c.inkSecondary : c.primaryInk)
                .copyWith(fontFeatures: SeenFonts.tabular)),
      ),
    );
  }
}
