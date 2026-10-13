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
    // actions pinned to the bottom.
    final mq = MediaQuery.of(context);
    final top = mq.padding.top > 80 ? mq.padding.top : 80.0;

    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        // The minimum height pins the actions to the bottom of tall screens;
        // short screens scroll instead.
        child: LayoutBuilder(
          builder: (context, box) {
            // Keeps a 440 px column on wide screens.
            final side = box.maxWidth > 480 ? (box.maxWidth - 440) / 2 : 20.0;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(side, top, side, 18 + mq.padding.bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ExcludeSemantics(child: _HeroCard()),
                          const SizedBox(height: 40),
                          // Figma 4:217 aligns the copy to the start edge.
                          Text(l10n.welcomeTitle, style: type.display),
                          const SizedBox(height: 16),
                          Text(
                            l10n.welcomeSubtitle,
                            style: type.body.copyWith(color: c.inkSecondary),
                          ),
                          // 16 + a 120 px spacer + 16 down to the buttons.
                          const SizedBox(height: 152),
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
                          const SizedBox(height: 16),
                          // Figma: the outline button is the 52 px (M) size.
                          SeenButton.outline(
                            label: l10n.welcomeCreateAgency,
                            expand: true,
                            onPressed: onCreateAccount,
                          ),
                          const SizedBox(height: 16),
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
            );
          },
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
