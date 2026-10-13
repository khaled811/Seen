import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';

/// Screen 02 · Welcome (Figma 4:217): the unauthenticated entry point. Hero
/// card, headline, a primary "sign in" and an outline "create agency account".
/// Navigation is delegated to the caller ([onSignIn], [onCreateAccount]).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onSignIn, required this.onCreateAccount});

  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  // Hero card geometry from Figma: a 350x300 card (r28) inside a 422x372
  // canvas that also held the drop shadow.
  static const _cardW = 350.0;
  static const _cardH = 300.0;
  static const _canvasW = 422.0;
  static const _canvasH = 372.0;
  static const _canvasDx = 36.0;
  static const _canvasDy = 12.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);

    // Figma 4:217: hero card top edge 80px from the screen top (never inside
    // the status bar), 20px side margins, copy centered under the card, and the
    // actions pinned to the bottom (24-32px above the screen edge).
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: LayoutBuilder(builder: (context, box) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, safeTop > 80 ? safeTop : 80, 20, 28 + safeBottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const ExcludeSemantics(child: _HeroCard()),
                            const SizedBox(height: 40),
                            Text(l10n.welcomeTitle, textAlign: TextAlign.center, style: type.display),
                            const SizedBox(height: 14),
                            Text(
                              l10n.welcomeSubtitle,
                              textAlign: TextAlign.center,
                              style: type.body.copyWith(color: c.inkSecondary),
                            ),
                            const SizedBox(height: SeenSpace.s8),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SeenButton(
                              label: l10n.loginTitle,
                              size: SeenButtonSize.large,
                              expand: true,
                              onPressed: onSignIn,
                            ),
                            const SizedBox(height: 12),
                            SeenButton.outline(
                              label: l10n.welcomeCreateAgency,
                              size: SeenButtonSize.large,
                              expand: true,
                              onPressed: onCreateAccount,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              l10n.welcomeTerms,
                              textAlign: TextAlign.center,
                              style: type.caption.copyWith(color: c.inkMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: WelcomeScreen._cardW / WelcomeScreen._cardH,
      child: LayoutBuilder(builder: (context, box) {
        final k = box.maxWidth / WelcomeScreen._cardW; // scale card -> available width
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Drop shadow (Figma: balance-card elevation), drawn natively
            // because flutter_svg ignores SVG filters.
            const DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(SeenRadius.r28),
                boxShadow: SeenShadows.balanceCard,
              ),
              child: SizedBox.expand(),
            ),
            Positioned(
              left: -WelcomeScreen._canvasDx * k,
              top: -WelcomeScreen._canvasDy * k,
              width: WelcomeScreen._canvasW * k,
              height: WelcomeScreen._canvasH * k,
              child: SvgPicture.asset(SeenVectors.welcomeHero, fit: BoxFit.fill),
            ),
          ],
        );
      }),
    );
  }
}
