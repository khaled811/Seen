import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';

/// Card recipe: surface + 1 px border + soft shadow, radius 22.
class SpiritualCard extends StatelessWidget {
  const SpiritualCard({
    super.key,
    required this.child,
    this.compact = false,
    this.padding,
    this.color,
    this.borderColor,
    this.radius = SpiritualRadius.card,
  });

  final Widget child;

  /// 16 dp padding instead of 20.
  final bool compact;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Container(
      padding: padding ??
          EdgeInsets.all(compact ? SpiritualSpace.s16 : SpiritualSpace.s20),
      decoration: BoxDecoration(
        color: color ?? t.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? t.borderCard),
        boxShadow: SpiritualTokens.cardShadow,
      ),
      child: child,
    );
  }
}
