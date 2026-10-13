import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';

/// Figma 16 — the agency request is waiting for the operations team. Reached
/// after the create-account form. (The auth session carries no agent status
/// yet, so a pending agent signing in cannot be routed here from the gate.)
class AgencyPendingApprovalScreen extends StatelessWidget {
  const AgencyPendingApprovalScreen({super.key, required this.onBackToLogin});

  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Scaffold(
      body: SeenScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            excludeSemantics: true,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(color: SeenBrand.violet20, shape: BoxShape.circle),
                              child: SizedBox(
                                width: 132,
                                height: 132,
                                child: Center(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: c.card,
                                      borderRadius: const BorderRadius.all(SeenRadius.r28),
                                      boxShadow: SeenShadows.card,
                                    ),
                                    child: SizedBox(
                                      width: 76,
                                      height: 76,
                                      child: Icon(SeenIcons.clock, size: 38, color: c.primary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: SeenSpace.s6),
                          Text(l10n.agencyPendingTitle, textAlign: TextAlign.center, style: t.h1),
                          const SizedBox(height: SeenSpace.s2),
                          Text(
                            l10n.agencyPendingBody,
                            textAlign: TextAlign.center,
                            style: t.body.copyWith(color: c.inkSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SeenButton.secondary(
                  label: l10n.agencyPendingSupportAction,
                  icon: SeenIcons.headset,
                  expand: true,
                  onPressed: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(l10n.agencyPendingSupportNote))),
                ),
                const SizedBox(height: SeenSpace.s3),
                SeenButton(label: l10n.agencyPendingBackAction, expand: true, onPressed: onBackToLogin),
                const SizedBox(height: SeenSpace.s4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
