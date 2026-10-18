// "Switch to English?" (Figma ACC-05): the interface direction flips, so ask first.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_typography.dart';

/// Resolves `true` when the user confirmed the switch to [toEnglish] ? English : Arabic.
Future<bool> showLanguageConfirmDialog(BuildContext context, {required bool toEnglish}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => _LanguageConfirmDialog(toEnglish: toEnglish),
  );
  return confirmed ?? false;
}

class _LanguageConfirmDialog extends StatelessWidget {
  const _LanguageConfirmDialog({required this.toEnglish});

  final bool toEnglish;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    return Dialog(
      backgroundColor: c.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(26))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(17))),
              child: SizedBox(width: 56, height: 56, child: Icon(SeenIcons.globe, size: 31, color: SeenBrand.violet)),
            ),
            const SizedBox(height: 12),
            Text(s.languageSwitchTitle(toEnglish), textAlign: TextAlign.center, style: t.h2),
            const SizedBox(height: 12),
            Text(s.languageSwitchBody(toEnglish), textAlign: TextAlign.center, style: t.body.copyWith(color: c.inkSecondary)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SeenButton.outline(label: s.cancelAction, expand: true, onPressed: () => Navigator.of(context).pop(false)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SeenButton(label: s.languageSwitchAction, expand: true, onPressed: () => Navigator.of(context).pop(true)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
