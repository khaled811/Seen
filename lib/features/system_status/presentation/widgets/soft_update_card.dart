// Optional update (Figma SYS-05, soft): a card over the app with "Later" and "Update".
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';

class SoftUpdateCard extends StatelessWidget {
  const SoftUpdateCard(
      {super.key,
      required this.version,
      this.note,
      required this.onUpdate,
      required this.onLater});

  final String version;
  final String? note;
  final VoidCallback? onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SeenBrand.violet05,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: SeenBrand.violet40),
        boxShadow: SeenShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.updateOptionalTitle, style: t.label),
                  Text(s.updateVersionLine(version, note),
                      style: t.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SeenButton.secondary(
                label: s.updateNow,
                size: SeenButtonSize.small,
                onPressed: onUpdate),
            const SizedBox(width: 4),
            SeenButton.ghost(
                label: s.updateLater,
                size: SeenButtonSize.small,
                onPressed: onLater),
          ],
        ),
      ),
    );
  }
}
