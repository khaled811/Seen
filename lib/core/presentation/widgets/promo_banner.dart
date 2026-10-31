// PromoBanner — Figma "Promo banner": soft violet gradient with the brand grid
// pattern bleeding off the corner, a badge + title + subtitle and an XS CTA.
// Content is supplied by the caller (the home screen gets it from `activeAds`).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_vectors.dart';
import 'actions.dart';

class SeenPromoBanner extends StatelessWidget {
  const SeenPromoBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.badge,
    this.onAction,
  });

  final String? badge;
  final String title;
  final String subtitle;
  /// Null hides the button (a banner with nothing to open).
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r22);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: SeenBrand.gradientPromo,
        borderRadius: radius,
        border: Border.all(color: c.border),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              left: -31,
              top: -111,
              width: 232.8,
              height: 335.2,
              child: ExcludeSemantics(child: SvgPicture.asset(SeenVectors.patternGridPromo, fit: BoxFit.fill)),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (badge != null) Text(badge!, style: type.caption.copyWith(color: c.primary)),
                        if (badge != null) const SizedBox(height: SeenSpace.s1),
                        Text(title, style: type.title),
                        const SizedBox(height: SeenSpace.s1),
                        Text(subtitle, style: type.caption.copyWith(color: c.inkSecondary)),
                      ],
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(width: SeenSpace.s3),
                    SeenButton(
                      label: actionLabel!,
                      size: SeenButtonSize.extraSmall,
                      onPressed: onAction,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
