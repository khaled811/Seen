import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';

/// "أنت تواجه القبلة" (sage) or "استدر يمينًا ١٢°" (accent), live-announced.
class QiblaStatusPill extends StatelessWidget {
  const QiblaStatusPill({
    super.key,
    required this.locked,
    required this.turn,
    required this.waiting,
  });

  final bool locked;

  /// Signed shortest turn in degrees (positive = right); null while waiting.
  final double? turn;
  final bool waiting;

  static String textFor({required bool locked, required double? turn}) {
    if (locked) return SpiritualStrings.facingQibla;
    if (turn == null) return SpiritualStrings.waitingCompass;
    final off = toArabicDigits(turn.abs().round());
    return '${turn > 0 ? SpiritualStrings.turnRight : SpiritualStrings.turnLeft} $off°';
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final bg = locked ? t.sageTint : t.accentTint;
    final fg = locked ? t.sageInk : t.accent;
    final text = textFor(locked: locked, turn: turn);
    final icon = locked
        ? Icons.check
        : (turn == null
            ? Icons.explore_outlined
            : (turn! > 0 ? Icons.rotate_right : Icons.rotate_left));
    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: SpiritualMotion.of(context, SpiritualMotion.base),
        constraints: const BoxConstraints(minHeight: SpiritualSpace.minTap),
        padding: const EdgeInsets.symmetric(
          horizontal: SpiritualSpace.s20,
          vertical: SpiritualSpace.s6,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(width: SpiritualSpace.s10),
            Flexible(
              child: Text(
                text,
                style: SpiritualType.bodyStrong.copyWith(
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
