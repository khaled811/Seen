// EmptyState — Figma "Requests · Empty" / "Pending approval" illustration:
// a soft violet disc holding a white tile with a service glyph, then title,
// message and an optional primary action. Native (no raster/SVG art).
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import 'actions.dart';
import 'svg_icon.dart';

class SeenEmptyState extends StatelessWidget {
  const SeenEmptyState({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String iconAsset;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              excludeSemantics: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: SeenBrand.gradientPromo,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border),
                ),
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: const BorderRadius.all(SeenRadius.r22),
                        boxShadow: const [
                          BoxShadow(color: Color(0x1F2C186A), offset: Offset(0, 12), blurRadius: 16),
                        ],
                      ),
                      child: SizedBox(width: 64, height: 64, child: Center(child: SeenSvgIcon(iconAsset, size: 36))),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: SeenSpace.s6),
            Text(title, textAlign: TextAlign.center, style: type.h2),
            const SizedBox(height: SeenSpace.s3),
            Text(message, textAlign: TextAlign.center, style: type.body.copyWith(color: c.inkSecondary)),
            if (actionLabel != null) ...[
              const SizedBox(height: SeenSpace.s5),
              SeenButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
