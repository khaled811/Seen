import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';
import 'press_scale.dart';

/// Outlined secondary button (48 min height) for destructive or rare actions
/// such as "إنهاء النسك" and "تصفير".
class SpiritualOutlinedButton extends StatelessWidget {
  const SpiritualOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final radius = BorderRadius.circular(SpiritualRadius.button);
    return PressScale(
      onTap: onPressed,
      borderRadius: radius,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Container(
          width: expand ? double.infinity : null,
          constraints: const BoxConstraints(
            minHeight: SpiritualSpace.minTap,
            minWidth: SpiritualSpace.minTap,
          ),
          padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: t.borderStrong),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SpiritualType.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: t.inkBody,
            ),
          ),
        ),
      ),
    );
  }
}
