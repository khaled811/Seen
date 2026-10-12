// StatCard — Figma dashboard stat: a coloured dot + caption and a big value.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';

class SeenStatCard extends StatelessWidget {
  const SeenStatCard({super.key, required this.label, required this.value, required this.dotColor});

  final String label;

  /// Pre-formatted (e.g. SeenStrings.numeral).
  final String value;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r18);
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: radius,
          border: Border.all(color: c.border),
          boxShadow: SeenShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    child: const SizedBox(width: 6, height: 6),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.caption.copyWith(color: c.inkSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SeenSpace.s1),
              Text(value, style: type.h1),
            ],
          ),
        ),
      ),
    );
  }
}
