// "Sign out?" (Figma AUTH-14): a confirmation that also says when signing out
// would cut an unfinished document upload short.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

/// Resolves to `true` when the agent confirms. [pendingReferences] are the requests
/// whose uploads are still running (empty = nothing to warn about).
Future<bool?> showLogoutConfirmDialog(BuildContext context, {List<String> pendingReferences = const []}) {
  return showDialog<bool>(
    context: context,
    barrierColor: const Color(0x521B1530),
    builder: (_) => _LogoutDialog(pendingReferences: pendingReferences),
  );
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog({required this.pendingReferences});

  final List<String> pendingReferences;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final tone = SeenRequestStatus.rejected.colors;
    final body = switch (pendingReferences.length) {
      0 => l10n.accountSignOutConfirmBody,
      1 => l10n.logoutPendingUpload(SeenFormat.isolate(pendingReferences.first)),
      final n => l10n.logoutPendingUploads(s.numeral(n)),
    };
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: l10n.accountSignOutConfirmTitle,
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
                DecoratedBox(
                  decoration: BoxDecoration(color: tone.bg, borderRadius: const BorderRadius.all(Radius.circular(17))),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Center(child: SeenSvgIcon(SeenVectors.accountLogout, size: 31, color: tone.fg)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.accountSignOutConfirmTitle, textAlign: TextAlign.center, style: t.h2),
                const SizedBox(height: 12),
                Text(body, textAlign: TextAlign.center, style: t.body.copyWith(color: c.inkSecondary)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SeenButton.destructive(
                        label: l10n.logoutConfirmAction,
                        expand: true,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                    const SizedBox(width: SeenSpace.s3),
                    Expanded(
                      child: SeenButton.outline(
                        label: l10n.cancel,
                        expand: true,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
