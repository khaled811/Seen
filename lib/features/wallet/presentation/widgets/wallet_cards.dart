// Wallet cards (Figma 11 / 12): usage bar, pending top-up and the bank
// details card with one-tap copy.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
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

/// Held vs. available split of the credit balance, drawn as a two-part bar.
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
    final total = available + hold;
    final heldFlex = total <= 0 ? 0 : (hold / total * 1000).round().clamp(0, 1000);
    final heldText = SeenFormat.usd(hold);
    final availableText = SeenFormat.usd(available);
    return Semantics(
      container: true,
      label: '${heldValue(heldText)} ${availableValue(availableText)}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: _cardDecoration(c),
        child: Padding(
          padding: const EdgeInsets.all(SeenSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.all(SeenRadius.full),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (heldFlex > 0) Expanded(flex: heldFlex, child: const ColoredBox(color: SeenBrand.violet80)),
                      if (heldFlex < 1000)
                        Expanded(flex: 1000 - heldFlex, child: const ColoredBox(color: SeenBrand.violet20)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: SeenSpace.s3),
              Row(
                children: [
                  Expanded(child: _Legend(color: SeenBrand.violet80, label: heldLabel, value: heldText)),
                  const SizedBox(width: SeenSpace.s3),
                  Expanded(child: _Legend(color: SeenBrand.violet20, label: availableLabel, value: availableText)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          DecoratedBox(decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: const SizedBox(width: 8, height: 8)),
          const SizedBox(width: 6),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.inkMuted))),
        ]),
        const SizedBox(height: 2),
        Text(value, textDirection: TextDirection.ltr, style: t.bodyStrong.copyWith(fontFeatures: SeenFonts.tabular)),
      ],
    );
  }
}

/// A top-up that is still waiting for review.
class SeenPendingTopUpCard extends StatelessWidget {
  const SeenPendingTopUpCard({super.key, required this.title, required this.subtitle, required this.statusLabel});

  final String title;
  final String subtitle;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SeenBrand.violet05,
        borderRadius: const BorderRadius.all(SeenRadius.r18),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SeenSpace.s3),
        child: Row(
          children: [
            Icon(SeenIcons.clock, size: 20, color: c.primary),
            const SizedBox(width: SeenSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, textDirection: TextDirection.ltr, style: t.bodyStrong),
                  Text(subtitle, style: t.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
            Text(statusLabel, style: t.chipS.copyWith(color: c.primary)),
          ],
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
    Widget row(String label, String value, {bool ltr = false, bool copy = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: SeenSpace.s2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: t.caption.copyWith(color: c.inkMuted)),
                    const SizedBox(height: 2),
                    Text(value, textDirection: ltr ? TextDirection.ltr : null, style: t.bodyStrong),
                  ],
                ),
              ),
              if (copy)
                Semantics(
                  button: true,
                  label: copyLabel,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => _copy(context, value),
                    borderRadius: const BorderRadius.all(SeenRadius.full),
                    child: Padding(
                      padding: const EdgeInsets.all(SeenSpace.s2),
                      child: Icon(SeenIcons.copy, size: 20, color: c.primary),
                    ),
                  ),
                ),
            ],
          ),
        );

    return DecoratedBox(
      decoration: _cardDecoration(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: SeenSpace.s2),
        child: Column(
          children: [
            row(details.bankName, details.accountName),
            Divider(height: 1, color: c.border),
            row(ibanLabel, details.iban, ltr: true, copy: true),
            Divider(height: 1, color: c.border),
            row(currencyLabel, details.currency, ltr: true),
          ],
        ),
      ),
    );
  }
}
