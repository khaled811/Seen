// ExtendedFab — Figma "Extended FAB": a 56px CTA-gradient pill (r20) with a
// label and a plus glyph, lifted by the ticket shadow.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_vectors.dart';
import 'svg_icon.dart';

class SeenExtendedFab extends StatelessWidget {
  const SeenExtendedFab({super.key, required this.label, required this.onPressed, this.iconAsset = SeenVectors.agentsPlus});

  final String label;
  final VoidCallback? onPressed;

  /// The exported Figma plus by default.
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r20);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(borderRadius: radius, boxShadow: SeenShadows.ticket),
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: const BoxDecoration(gradient: SeenBrand.gradientCta, borderRadius: radius),
            child: InkWell(
              onTap: onPressed,
              borderRadius: radius,
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 22, end: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SeenSvgIcon(iconAsset, size: 22, color: c.onPrimary),
                      const SizedBox(width: SeenSpace.s2),
                      Text(label, style: type.bodyStrong.copyWith(color: c.onPrimary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
