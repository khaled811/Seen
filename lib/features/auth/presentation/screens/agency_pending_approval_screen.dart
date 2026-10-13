import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';

/// Figma 16 (node 20:667) — the agency request is waiting for the operations
/// team: illustration, title, copy, a review chip and a three-step card, with
/// one "contact support" action. Reached after the create-account form; the
/// system back gesture (handled by the entry flow) leaves it. The auth session
/// carries no agent status yet, so a pending agent signing in cannot be routed
/// here from the gate.
class AgencyPendingApprovalScreen extends StatelessWidget {
  const AgencyPendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    // SafeArea below adds the status-bar inset, so subtract it to land at 180.
    final safeTop = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: SeenScreenBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                // Figma: the body starts 180 px from the screen top.
                padding: EdgeInsets.fromLTRB(28, 180 - safeTop, 28, 24),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Semantics(
                        excludeSemantics: true,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: SeenBrand.gradientPromo,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.border),
                          ),
                          child: SizedBox(
                            width: 140,
                            height: 140,
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: c.card,
                                  borderRadius: const BorderRadius.all(SeenRadius.r22),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x1F2C186A), blurRadius: 16, offset: Offset(0, 12)),
                                  ],
                                ),
                                child: const SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: Center(child: SeenSvgIcon(SeenVectors.authClock, size: 36)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(l10n.agencyPendingTitle, textAlign: TextAlign.center, style: t.h1),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          l10n.agencyPendingBody,
                          textAlign: TextAlign.center,
                          style: t.body.copyWith(color: c.inkSecondary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SeenStatusChip(
                        status: SeenRequestStatus.underReview,
                        label: s.review,
                        size: SeenStatusChipSize.medium,
                      ),
                      const SizedBox(height: 16),
                      _StepsCard(
                        steps: [
                          (l10n.agencyPendingStepReceived, _StepState.done),
                          (l10n.agencyPendingStepReview, _StepState.current),
                          (l10n.agencyPendingStepActivate, _StepState.upcoming),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SeenActionBar(
              actions: [
                SeenButton.outline(
                  label: l10n.agencyPendingSupportAction,
                  expand: true,
                  onPressed: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(l10n.agencyPendingSupportNote))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { done, current, upcoming }

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps});

  final List<(String, _StepState)> steps;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.all(SeenRadius.r22),
          border: Border.all(color: c.border),
          boxShadow: SeenShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    switch (steps[i].$2) {
                      _StepState.done => const DecoratedBox(
                          decoration: BoxDecoration(gradient: SeenBrand.gradientCta, shape: BoxShape.circle),
                          child: SizedBox(width: 20, height: 20),
                        ),
                      _StepState.current => DecoratedBox(
                          decoration: BoxDecoration(
                            color: SeenBrand.violet10,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.primary, width: 2),
                          ),
                          child: const SizedBox(width: 20, height: 20),
                        ),
                      _StepState.upcoming => DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.card,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.borderStrong, width: 1.5),
                          ),
                          child: const SizedBox(width: 20, height: 20),
                        ),
                    },
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        steps[i].$1,
                        style: switch (steps[i].$2) {
                          _StepState.done => t.body.copyWith(color: c.ink),
                          _StepState.current => t.bodyStrong.copyWith(color: c.ink),
                          _StepState.upcoming => t.body.copyWith(color: c.inkMuted),
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
