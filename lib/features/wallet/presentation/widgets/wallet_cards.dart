// Wallet cards (Figma 11 / 12): usage bar, pending top-up and the bank
// details card with one-tap copy.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

BoxDecoration _cardDecoration(SeenColors c) => BoxDecoration(
      color: c.card,
      borderRadius: const BorderRadius.all(SeenRadius.r22),
      border: Border.all(color: c.border),
      boxShadow: SeenShadows.card,
    );

/// Figma "Usage" card (node 18:488): held / available labels, a two-segment bar
/// (held in amber, available in the CTA gradient) and a two-item legend.
class SeenWalletUsageCard extends StatelessWidget {
  const SeenWalletUsageCard({
    super.key,
    required this.available,
    required this.hold,
    required this.heldLabel,
    required this.availableLabel,
    required this.heldValue,
    required this.availableValue,
  });

  /// Major units.
  final num available;
  final num hold;
  final String heldLabel;
  final String availableLabel;
  final String Function(String amount) heldValue;
  final String Function(String amount) availableValue;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final total = available + hold;
    final heldFlex = total <= 0 ? 0 : (hold / total * 1000).round().clamp(0, 1000);
    final heldText = SeenFormat.usd(hold);
    final availableText = SeenFormat.usd(available);
    const segment = BorderRadius.all(Radius.circular(4));

    Widget legend(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: const SizedBox(width: 8, height: 8)),
            const SizedBox(width: 6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.inkMuted))),
          ],
        );

    return Semantics(
      container: true,
      label: '${heldValue(heldText)} ${availableValue(availableText)}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: _cardDecoration(c),
        child: Padding(
          padding: const EdgeInsets.all(SeenSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Available leads (start edge), held trails, as drawn.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      availableValue(availableText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.end,
                      style: t.label.copyWith(color: c.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      heldValue(heldText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: t.label.copyWith(color: c.inkSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (heldFlex < 1000)
                      Expanded(
                        flex: 1000 - heldFlex,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(gradient: SeenBrand.gradientCta, borderRadius: segment),
                          child: SizedBox.expand(),
                        ),
                      ),
                    if (heldFlex > 0 && heldFlex < 1000) const SizedBox(width: 3),
                    if (heldFlex > 0)
                      Expanded(
                        flex: heldFlex,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(color: SeenBrand.progressWaiting, borderRadius: segment),
                          child: SizedBox.expand(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(child: legend(SeenBrand.violet, availableLabel)),
                  const SizedBox(width: 14),
                  Flexible(child: legend(SeenBrand.progressWaiting, heldLabel)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma "Pending top-up" (node 18:507): soft violet gradient, a white clock
/// tile, the amount and when it was sent, and the review chip at the far end.
class SeenPendingTopUpCard extends StatelessWidget {
  const SeenPendingTopUpCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: SeenBrand.gradientSoft,
        borderRadius: const BorderRadius.all(SeenRadius.r18),
        border: Border.all(color: c.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(SeenRadius.r18),
          child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: c.card, borderRadius: const BorderRadius.all(SeenRadius.r12)),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Center(child: SeenSvgIcon(SeenVectors.walletClock, size: 22)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, textDirection: TextDirection.ltr, style: t.bodyStrong.copyWith(color: c.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: t.caption.copyWith(color: c.inkSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SeenStatusChip(status: SeenRequestStatus.underReview, label: statusLabel),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

/// Where the agent wires the money. Values are display-only data supplied by
/// the caller; the app never invents them.
class TopUpBankDetails {
  const TopUpBankDetails({required this.bankName, required this.accountName, required this.iban, this.currency = 'USD'});

  final String bankName;
  final String accountName;
  final String iban;
  final String currency;
}

/// Figma "Bank details card" (node 18:654): violet gradient, grid pattern, the
/// white logo, bank name, IBAN with a copy pill, currency and beneficiary.
class SeenBankDetailsCard extends StatelessWidget {
  const SeenBankDetailsCard({
    super.key,
    required this.details,
    required this.ibanLabel,
    required this.beneficiaryLabel,
    required this.currencyLabel,
    required this.copyLabel,
    required this.copiedMessage,
  });

  final TopUpBankDetails details;
  final String ibanLabel;
  final String beneficiaryLabel;
  final String currencyLabel;
  final String copyLabel;
  final String copiedMessage;

  Future<void> _copy(BuildContext context, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(copiedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final white = c.onPrimary;
    final dim = t.caption.copyWith(color: white.withOpacity(0.8));
    const radius = BorderRadius.all(SeenRadius.r24);
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: Color(0x1A2C186A), blurRadius: 16, spreadRadius: -6, offset: Offset(0, 8)),
          BoxShadow(color: Color(0x4D5B36DA), blurRadius: 48, spreadRadius: -12, offset: Offset(0, 24)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [SeenBrand.violet, Color(0xFFC3B0FC)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -40,
                top: -110,
                width: 291,
                height: 419,
                child: ExcludeSemantics(
                  child: SvgPicture.asset(SeenVectors.walletPatternGrid, fit: BoxFit.fill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(details.bankName, style: t.title.copyWith(color: white))),
                        ExcludeSemantics(
                          child: SvgPicture.asset(SeenVectors.logoWhite, width: 69.9, height: 35.2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(ibanLabel, style: dim),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            details.iban,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.end,
                            style: t.title.copyWith(color: white, fontFeatures: SeenFonts.tabular),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: copyLabel,
                          excludeSemantics: true,
                          child: Material(
                            color: white.withOpacity(0.22),
                            shape: const StadiumBorder(),
                            child: InkWell(
                              onTap: () => _copy(context, details.iban),
                              customBorder: const StadiumBorder(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Text(copyLabel, style: t.caption.copyWith(color: white)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(beneficiaryLabel, style: dim),
                              const SizedBox(height: 2),
                              Text(details.accountName, style: t.bodyStrong.copyWith(color: white)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(currencyLabel, style: dim),
                            const SizedBox(height: 2),
                            Text(
                              details.currency,
                              textDirection: TextDirection.ltr,
                              style: t.bodyStrong.copyWith(color: white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
