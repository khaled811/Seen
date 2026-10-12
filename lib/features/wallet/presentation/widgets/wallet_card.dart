// WalletCard — navy balance card: available balance, Top-Up button, and a
// Hold | Total split. The same widget is used on Home and Wallet so the
// numbers always match.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

class SeenWalletCard extends StatelessWidget {
  const SeenWalletCard({
    super.key,
    required this.available,
    required this.hold,
    this.creditLimit,
    this.onTopUp,
    this.showTopUp = true,
    this.backgroundPattern,
  });

  final num available;
  final num hold;

  /// Optional third column.
  final num? creditLimit;
  final VoidCallback? onTopUp;
  final bool showTopUp;

  /// Optional decorative image (e.g. `assets/images/pattern-flight.png`)
  /// drawn faintly behind the card's content, clipped to its own radius.
  /// Purely cosmetic — leave null for the plain navy card.
  final String? backgroundPattern;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final s = SeenStrings.of(context);

    return Semantics(
      container: true,
      label: '${s.availableBalance} ${SeenFormat.money(available)} USD',
      child: Container(
        decoration: BoxDecoration(color: c.primary, borderRadius: const BorderRadius.all(SeenRadius.lg)),
        clipBehavior: backgroundPattern == null ? Clip.none : Clip.antiAlias,
        child: Stack(
          children: [
            if (backgroundPattern != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.32,
                  child: Image.asset(backgroundPattern!, fit: BoxFit.cover, alignment: Alignment.centerRight),
                ),
              ),
            _SeenWalletCardContent(
              available: available,
              hold: hold,
              creditLimit: creditLimit,
              onTopUp: onTopUp,
              showTopUp: showTopUp,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeenWalletCardContent extends StatelessWidget {
  const _SeenWalletCardContent({
    required this.available,
    required this.hold,
    required this.creditLimit,
    required this.onTopUp,
    required this.showTopUp,
  });

  final num available;
  final num hold;
  final num? creditLimit;
  final VoidCallback? onTopUp;
  final bool showTopUp;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final s = SeenStrings.of(context);
    final text = Theme.of(context).textTheme;
    final caption = text.labelMedium!.copyWith(color: c.onPrimaryMuted, fontWeight: FontWeight.w500);
    final sub = seenStyle(15, 22, FontWeight.w600, c.onPrimary).copyWith(fontFeatures: SeenFonts.tabular);
    final split = c.onPrimaryMuted.withAlpha(0x47); // 28%

    Widget cell(String label, num value, {IconData? icon}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(SeenSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (icon != null) ...[Icon(icon, size: 14, color: c.onPrimaryMuted), const SizedBox(width: 4)],
                  Text(label, style: caption),
                ]),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(SeenFormat.money(value), style: sub, textDirection: TextDirection.ltr),
                ),
              ],
            ),
          ),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(SeenSpace.s4, SeenSpace.s4, SeenSpace.s4, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(SeenIcons.wallet, size: 16, color: c.onPrimaryMuted),
                  const SizedBox(width: SeenSpace.s1),
                  Expanded(child: Text(s.availableBalance, style: caption)),
                  if (showTopUp)
                    Material(
                      color: c.card,
                      borderRadius: const BorderRadius.all(SeenRadius.sm),
                      child: InkWell(
                        onTap: onTopUp,
                        borderRadius: const BorderRadius.all(SeenRadius.sm),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(SeenIcons.plus, size: 18, color: c.primaryInk),
                            const SizedBox(width: 6),
                            Text(s.topUp, style: seenStyle(14, 20, FontWeight.w600, c.primaryInk)),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: SeenSpace.s1),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(SeenFormat.money(available), style: SeenType.of(context).amountXl),
                      const SizedBox(width: 6),
                      Text('USD', style: text.labelMedium!.copyWith(color: c.onPrimaryMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SeenSpace.s4),
        DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: split))),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cell(s.onHold, hold, icon: SeenIcons.lock),
                VerticalDivider(width: 1, thickness: 1, color: split),
                cell(s.total, available + hold),
                if (creditLimit != null) ...[
                  VerticalDivider(width: 1, thickness: 1, color: split),
                  cell(s.creditLimit, creditLimit!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
