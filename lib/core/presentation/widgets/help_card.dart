// HelpCard — Figma "Help": soft violet panel with a short prompt and a
// secondary action ("Contact").
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import 'actions.dart';

class SeenHelpCard extends StatelessWidget {
  const SeenHelpCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: SeenBrand.gradientSoft,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SeenSpace.s4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: type.bodyStrong),
                  Text(subtitle, style: type.caption.copyWith(color: c.inkSecondary)),
                ],
              ),
            ),
            const SizedBox(width: SeenSpace.s3),
            SeenButton.secondary(label: actionLabel, size: SeenButtonSize.small, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}
