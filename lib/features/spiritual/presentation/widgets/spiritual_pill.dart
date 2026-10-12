import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';

enum PillVariant { neutral, accent, success, solid }

/// Non-interactive status pill.
class SpiritualPill extends StatelessWidget {
  const SpiritualPill({
    super.key,
    required this.label,
    this.variant = PillVariant.neutral,
    this.icon,
    this.dot = false,
    this.height = 36,
  });

  final String label;
  final PillVariant variant;
  final IconData? icon;

  /// Small leading status dot.
  final bool dot;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final (bg, fg) = switch (variant) {
      PillVariant.neutral => (t.surfaceMuted, t.inkBody),
      PillVariant.accent => (t.accentTint, t.accent),
      PillVariant.success => (t.sageTint, t.sageInk),
      PillVariant.solid => (t.accent, Colors.white),
    };
    return AnimatedContainer(
      duration: SpiritualMotion.of(context, SpiritualMotion.base),
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(
        horizontal: SpiritualSpace.s14,
        vertical: SpiritualSpace.s4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SpiritualRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: SpiritualSpace.s8),
          ],
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: SpiritualSpace.s6),
          ],
          Flexible(
            child: Text(
              label,
              style: SpiritualType.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
