import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_typography.dart';

/// Screen 01 · Splash (Figma 4:207). Shown while the persisted session is
/// being restored (`AuthInitial`): soft violet wash from the top, the vertical
/// brand lockup, and the powered-by line. Purely visual; navigation stays in
/// the auth gate.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Scaffold(
      backgroundColor: c.card,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Figma "Soft violet glow": a 438 px blurred violet disc centred at
          // (195, 143). flutter_svg ignores SVG blur filters, so the same glow
          // is a radial gradient (about 18 % violet fading to nothing).
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.66),
                radius: 0.8,
                colors: [Color(0x2E7B52F5), Color(0x00FFFFFF)],
              ),
            ),
          ),
          Align(
            // Figma places the lockup centre at ~45% of the height.
            alignment: const Alignment(0, -0.1),
            child: Semantics(
              label: AppLocalizations.of(context)!.appTitle,
              image: true,
              child: SvgPicture.asset(SeenVectors.logoVertical, width: 124, excludeFromSemantics: true),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 21),
                // The brand line is English in both locales, as drawn.
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    AppLocalizations.of(context)!.splashPoweredBy,
                    textAlign: TextAlign.center,
                    style: type.body.copyWith(color: c.inkMuted),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
