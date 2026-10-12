import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';
import 'press_scale.dart';

/// Filter chip: 48 tall, selected = accent fill with white text.
class SpiritualChip extends StatelessWidget {
  const SpiritualChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final radius = BorderRadius.circular(24);
    return Semantics(
      selected: selected,
      child: PressScale(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: SpiritualMotion.of(context, SpiritualMotion.fast),
          constraints: const BoxConstraints(minHeight: SpiritualSpace.minTap),
          padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s20),
          decoration: BoxDecoration(
            color: selected ? t.accent : t.surface,
            borderRadius: radius,
            border: Border.all(color: selected ? t.accent : t.borderControl),
          ),
          // widthFactor: hug the label (an aligned Container would stretch to
          // the full width inside a Wrap); height still fills the 48 dp.
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: SpiritualType.label.copyWith(
                color: selected ? Colors.white : t.inkBody,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
