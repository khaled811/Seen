import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';

/// "Session expired" (Figma AUTH-13): a blocking dialog over whatever screen the
/// user was on. The only way out is the sign-in button (no scrim tap, no system
/// back); completes when it is pressed.
///
/// The design also shows a "draft saved" line; the app has no drafts yet, so it
/// is not shown rather than promised (docs/BACKEND_MIGRATION_GAPS.md, section 12).
Future<void> showSessionExpiredDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x521B1530),
    builder: (_) => const _SessionExpiredDialog(),
  );
}

class _SessionExpiredDialog extends StatelessWidget {
  const _SessionExpiredDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          namesRoute: true,
          label: l10n.sessionExpiredTitle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.all(SeenRadius.r28),
              boxShadow: const [
                BoxShadow(color: Color(0x142C186A), blurRadius: 16, offset: Offset(0, 8)),
                BoxShadow(color: Color(0x385B36DA), blurRadius: 48, offset: Offset(0, 24)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(17))),
                    child: SizedBox(width: 56, height: 56, child: Center(child: SeenSvgIcon(SeenVectors.sessionClock, size: 31))),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.sessionExpiredTitle, textAlign: TextAlign.center, style: t.h2),
                  const SizedBox(height: 12),
                  Text(
                    l10n.sessionExpiredBody,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(color: c.inkSecondary),
                  ),
                  const SizedBox(height: 20),
                  SeenButton(
                    label: l10n.sessionExpiredAction,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
