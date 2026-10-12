import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';

/// A− · current size · A+ (docs/03 §3). Buttons dim at the ends of the six
/// steps.
class FontSizeControl extends StatelessWidget {
  const FontSizeControl({
    super.key,
    required this.size,
    required this.canShrink,
    required this.canGrow,
    required this.onSmaller,
    required this.onBigger,
  });

  final double size;
  final bool canShrink;
  final bool canGrow;
  final VoidCallback onSmaller;
  final VoidCallback onBigger;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(SpiritualRadius.button),
        border: Border.all(color: t.borderControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            label: 'A−',
            fontSize: 16,
            semanticLabel: SpiritualStrings.smallerFont,
            enabled: canShrink,
            onTap: onSmaller,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 36),
            child: Text(
              toArabicDigits(size.round()),
              textAlign: TextAlign.center,
              style: SpiritualType.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: t.inkBody,
              ),
            ),
          ),
          _StepButton(
            label: 'A+',
            fontSize: 21,
            semanticLabel: SpiritualStrings.biggerFont,
            enabled: canGrow,
            onTap: onBigger,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.fontSize,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final double fontSize;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return PressScale(
      onTap: enabled ? onTap : null,
      semanticLabel: semanticLabel,
      scale: 0.94,
      borderRadius: BorderRadius.circular(SpiritualRadius.control),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: SizedBox(
          width: 52,
          height: SpiritualSpace.minTap,
          child: Center(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                label,
                style: SpiritualType.label.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: t.inkPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
