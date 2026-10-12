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

    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        // Hero on top, copy + actions pinned to the bottom;
                        // on short screens the page scrolls instead.
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const ExcludeSemantics(child: _HeroCard()),
                          const SizedBox(height: SeenSpace.s6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(l10n.welcomeTitle, style: type.display),
                              const SizedBox(height: SeenSpace.s4),
                              Text(l10n.welcomeSubtitle, style: type.body.copyWith(color: c.inkSecondary)),
                              const SizedBox(height: SeenSpace.s8),
                              SeenButton(
                                label: l10n.loginTitle,
                                size: SeenButtonSize.large,
                                expand: true,
                                onPressed: onSignIn,
                              ),
                              const SizedBox(height: SeenSpace.s3),
                              SeenButton.outline(
                                label: l10n.welcomeCreateAgency,
                                expand: true,
                                onPressed: onCreateAccount,
                              ),
                              const SizedBox(height: SeenSpace.s4),
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
