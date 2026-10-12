import 'package:flutter/material.dart';

import '../spiritual_strings.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import 'spiritual_outlined_button.dart';
import 'spiritual_primary_button.dart';

/// Explicit confirmation for destructive actions (undo a lap, end the rite).
/// Resolves to true only when the user taps the confirm button; dismissing the
/// dialog any other way (back, tapping outside, "تراجع") is a no.
///
/// Buttons are stacked full-width so they stay large and legible at any text
/// scale.
Future<bool> showSpiritualConfirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
  String cancelLabel = SpiritualStrings.cancel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => SpiritualTheme(
      child: Builder(
        builder: (context) {
          final t = SpiritualTokens.of(context);
          return Dialog(
            backgroundColor: t.surface,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(SpiritualSpace.s20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SpiritualRadius.card),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SpiritualSpace.s20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: SpiritualType.section.copyWith(color: t.inkPrimary),
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: SpiritualSpace.s8),
                    Text(
                      message,
                      style: SpiritualType.body.copyWith(color: t.inkBody),
                    ),
                  ],
                  const SizedBox(height: SpiritualSpace.s20),
                  SpiritualPrimaryButton(
                    label: confirmLabel,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                  const SizedBox(height: SpiritualSpace.s10),
                  SpiritualOutlinedButton(
                    label: cancelLabel,
                    expand: true,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  return result ?? false;
}
