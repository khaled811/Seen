import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';
import 'press_scale.dart';

/// 48×48 round icon button. [semanticLabel] is mandatory: an icon alone is
/// meaningless to a screen reader.
class SpiritualIconButton extends StatelessWidget {
  const SpiritualIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color,
    this.filled = true,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color? color;

  /// Draws the white disc and border; false leaves only the glyph.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return PressScale(
      onTap: onPressed,
      scale: 0.94,
      semanticLabel: semanticLabel,
      borderRadius: BorderRadius.circular(SpiritualSpace.minTap / 2),
      child: Container(
        width: SpiritualSpace.minTap,
        height: SpiritualSpace.minTap,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? t.surface : null,
          border: filled ? Border.all(color: t.borderControl) : null,
        ),
        child: Icon(icon, size: 22, color: color ?? t.inkPrimary),
      ),
    );
  }
}
