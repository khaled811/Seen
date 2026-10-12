// BalanceCard — Figma "Balance card": CTA-violet gradient, white isometric
// pattern in the corner, white logo, a hide/show toggle, the credit balance in
// the Amount style and two meta chips (on hold, credit limit).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_format.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';
import '../foundation/seen_vectors.dart';

class SeenBalanceCard extends StatefulWidget {
  const SeenBalanceCard({
    super.key,
    required this.available,
    required this.hold,
    required this.caption,
    required this.holdLabel,
    required this.showSemanticLabel,
    required this.hideSemanticLabel,
    this.creditLimit,
    this.creditLimitLabel,
    this.onTap,
  });

  /// Amounts in major units (e.g. dollars), not cents.
  final num available;
  final num hold;
  final num? creditLimit;

  /// e.g. "رصيد دائن".
  final String caption;

  /// Build the chip text from the formatted amount, e.g. `(a) => 'محجوز $a'`.
  final String Function(String amount) holdLabel;
  final String Function(String amount)? creditLimitLabel;

  /// Accessible names of the eye toggle in each state.
  final String showSemanticLabel;
  final String hideSemanticLabel;
  final VoidCallback? onTap;

  @override
  State<SeenBalanceCard> createState() => _SeenBalanceCardState();
}

class _SeenBalanceCardState extends State<SeenBalanceCard> {
  // Display preference only (privacy at a glance); not persisted.
  bool _hidden = false;

  static const _mask = '••••••';

  String _usd(num v) => _hidden ? _mask : '${SeenFormat.money(v)} USD';

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final w = widget;
    final glass = c.onPrimary.withAlpha(0x38); // white @ 22%
    final creditLimitLabel = w.creditLimitLabel;

    Widget chip(String text) => DecoratedBox(
          decoration: BoxDecoration(color: glass, borderRadius: const BorderRadius.all(SeenRadius.full)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            // Amounts inside the label are isolated LTR runs (SeenFormat.isolate).
            child: Text(text, style: type.caption.copyWith(color: c.onPrimary)),
          ),
        );

    return Semantics(
      container: true,
      label: _hidden ? w.caption : '${w.caption} ${SeenFormat.money(w.available)} USD',
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: SeenBrand.gradientCard,
            borderRadius: BorderRadius.all(SeenRadius.r24),
            boxShadow: SeenShadows.balanceCard,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(SeenRadius.r24),
            child: InkWell(
              onTap: w.onTap,
              child: Stack(
                children: [
                  Positioned(
                    left: -175,
                    top: -128,
                    width: 406.4,
                    height: 291.2,
                    child: ExcludeSemantics(child: SvgPicture.asset(SeenVectors.patternIsometricWhite, fit: BoxFit.fill)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s5, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            ExcludeSemantics(
                              child: SvgPicture.asset(SeenVectors.logoWhite, width: 84, height: 42),
                            ),
                            const Spacer(),
                            Semantics(
                              button: true,
                              label: _hidden ? w.showSemanticLabel : w.hideSemanticLabel,
                              excludeSemantics: true,
                              child: Material(
                                color: glass,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => setState(() => _hidden = !_hidden),
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Icon(_hidden ? SeenIcons.eyeSlash : SeenIcons.eye, size: 20, color: c.onPrimary),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SeenSpace.s3),
                        Text(w.caption, style: type.label.copyWith(color: c.onPrimaryMuted)),
                        const SizedBox(height: 6),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Directionality(
                            textDirection: TextDirection.ltr, // "1,532.00 USD" never reorders
                            child: Text(_usd(w.available), style: type.amountXl),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: SeenSpace.s2,
                          runSpacing: SeenSpace.s2,
                          children: [
                            chip(w.holdLabel(SeenFormat.isolate(_usd(w.hold)))),
                            if (w.creditLimit != null && creditLimitLabel != null)
                              chip(creditLimitLabel(SeenFormat.isolate(_usd(w.creditLimit!)))),
                          ],
                        ),
                      ],
                    ),
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
