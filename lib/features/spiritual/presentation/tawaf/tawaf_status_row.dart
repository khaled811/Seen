import 'package:flutter/material.dart';

import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_pill.dart';

/// Status pill (flashes accent after an action) and the deliberately small
/// "undo lap" button, kept away from the main button.
class TawafStatusRow extends StatelessWidget {
  const TawafStatusRow({
    super.key,
    required this.status,
    required this.flash,
    required this.canUndo,
    required this.onUndo,
  });

  final String status;
  final bool flash;
  final bool canUndo;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final radius = BorderRadius.circular(SpiritualRadius.control);
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              liveRegion: true,
              child: SpiritualPill(
                label: status,
                icon: Icons.check,
                variant: flash ? PillVariant.accent : PillVariant.neutral,
                height: 40,
              ),
            ),
          ),
        ),
        const SizedBox(width: SpiritualSpace.s8),
        PressScale(
          onTap: canUndo ? onUndo : null,
          borderRadius: radius,
          child: Opacity(
            opacity: canUndo ? 1 : 0.45,
            child: Container(
              constraints: const BoxConstraints(minHeight: SpiritualSpace.minTap),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: radius,
                border: Border.all(color: t.borderStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.redo, size: 18, color: t.inkBody),
                  const SizedBox(width: SpiritualSpace.s6),
                  Text(
                    SpiritualStrings.undoLap,
                    style: SpiritualType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: t.inkBody,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
