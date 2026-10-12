// ServiceTile — Figma "Service tile": 104px card with a 40px service icon and a
// label. `soon` = dashed outline, muted icon and a "Soon" tag; not tappable.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import 'dashed_border.dart';
import 'svg_icon.dart';

class SeenServiceTile extends StatelessWidget {
  const SeenServiceTile({
    super.key,
    required this.label,
    required this.iconAsset,
    this.onTap,
    this.soon = false,
    this.soonLabel,
    this.caption,
    this.height = 104,
    this.labelLines = 1,
  });

  final String label;
  final String iconAsset;
  final VoidCallback? onTap;

  /// Coming-soon state: dashed border, muted icon, [soonLabel] tag, no tap.
  final bool soon;
  final String? soonLabel;

  /// Optional small line under the label (e.g. the price).
  final String? caption;
  final double height;
  final int labelLines;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r18);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SeenSvgIcon(iconAsset, size: 40, color: soon ? SeenBrand.violet40 : null),
          const SizedBox(height: SeenSpace.s2),
          Text(
            label,
            maxLines: labelLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: type.label.copyWith(color: c.ink),
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: type.caption.copyWith(color: c.inkMuted),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      button: !soon,
      enabled: !soon,
      label: soon && soonLabel != null ? '$label, $soonLabel' : label,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: soon
            ? SeenDashedBorder(
                color: c.borderStrong,
                radius: SeenRadius.r18.x,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.card, borderRadius: radius),
                  child: Stack(
                    children: [
                      Positioned.fill(child: content),
                      if (soonLabel != null)
                        PositionedDirectional(
                          top: 6.5,
                          start: 6.5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: c.primarySoft, borderRadius: const BorderRadius.all(SeenRadius.full)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                              child: Text(soonLabel!, style: type.caption.copyWith(color: c.primaryInk)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : DecoratedBox(
                decoration: const BoxDecoration(borderRadius: radius, boxShadow: SeenShadows.card),
                child: Material(
                  color: c.card,
                  shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: c.border)),
                  child: InkWell(onTap: onTap, borderRadius: radius, child: content),
                ),
              ),
      ),
    );
  }
}
