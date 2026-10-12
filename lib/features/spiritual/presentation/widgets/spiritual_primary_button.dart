import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';
import 'press_scale.dart';

/// Filled accent button. Standard: height 58, radius 16. [large]: height 96,
/// radius 26, optional [subtitle] hint and floating shadow (Tawaf counter).
class SpiritualPrimaryButton extends StatelessWidget {
  const SpiritualPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.trailingIcon,
    this.leadingIcon,
    this.large = false,
    this.color,
  });

  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;
  final IconData? leadingIcon;
  final bool large;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final radius = BorderRadius.circular(
      large ? SpiritualRadius.tile + 6 : SpiritualRadius.button,
    );
    final enabled = onPressed != null;
    return PressScale(
      onTap: onPressed,
      borderRadius: radius,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: large ? 96 : 58),
          padding: const EdgeInsets.symmetric(
            horizontal: SpiritualSpace.s20,
            vertical: SpiritualSpace.s10,
          ),
          decoration: BoxDecoration(
            color: color ?? t.accent,
            borderRadius: radius,
            boxShadow: large ? SpiritualTokens.floatingShadow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (leadingIcon != null) ...[
                          Icon(
                            leadingIcon,
                            color: Colors.white,
                            size: large ? 26 : 22,
                          ),
                          const SizedBox(width: SpiritualSpace.s10),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: SpiritualType.label.copyWith(
                              fontSize: large ? 23 : 19,
                              fontWeight:
                                  large ? FontWeight.w800 : FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: SpiritualType.caption.copyWith(
                          color: Colors.white.withOpacity(0.92),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: SpiritualSpace.s10),
                Icon(trailingIcon, color: Colors.white, size: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
