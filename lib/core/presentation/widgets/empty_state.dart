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
    this.topInset,
  });

  final String iconAsset;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// When set, the block hangs this far from the top instead of being centred
  /// (Figma 18 places it at a fixed offset under the header).
  final double? topInset;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final block = ConstrainedBox(
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
          // Figma: 14 px gaps plus 8 / 6 px spacers around the copy.
          const SizedBox(height: 36),
          Text(title, textAlign: TextAlign.center, style: type.h2),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: type.body.copyWith(color: c.inkSecondary)),
          if (actionLabel != null) ...[
            const SizedBox(height: 34),
            SizedBox(width: 220, child: SeenButton(label: actionLabel!, expand: true, onPressed: onAction)),
          ],
        ],
      ),
    );
    if (topInset != null) {
      return Align(
          alignment: Alignment.topCenter, child: Padding(padding: EdgeInsets.only(top: topInset!), child: block));
    }
    return Center(child: block);
  }
}
