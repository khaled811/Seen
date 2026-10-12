// BalanceBanner — wallet-vs-charge sufficiency check. Domain-agnostic (two
// `num`s only), reusable wherever a screen needs to show "can this amount
// be covered right now" (booking review, sub-agent funding, top-up, …).
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_format.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';
import '../foundation/seen_strings.dart';
import 'chrome.dart' show SeenLink;

/// Wallet vs pending charge. Enough = navy-soft panel; not enough = terracotta
/// with a "Top up" link — and the caller must disable the primary button.
class SeenBalanceBanner extends StatelessWidget {
  const SeenBalanceBanner({super.key, required this.available, required this.charge, this.onTopUp});

  final num available;
  final num charge;
  final VoidCallback? onTopUp;

  bool get isSufficient => available >= charge;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final s = SeenStrings.of(context);
    final text = Theme.of(context).textTheme;
    final ok = isSufficient;
    final muted = text.bodySmall!.copyWith(color: c.inkSecondary);
    final strong = text.bodySmall!.copyWith(color: c.ink, fontWeight: FontWeight.w600, fontFeatures: SeenFonts.tabular);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: SeenSpace.s3),
      decoration: BoxDecoration(
        color: ok ? c.primarySoft : c.dangerBg,
        borderRadius: const BorderRadius.all(SeenRadius.md),
        border: Border.all(color: ok ? c.primaryLine : c.dangerLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? SeenIcons.wallet : SeenIcons.alert, size: 20, color: ok ? c.primaryInk : c.dangerFg),
          const SizedBox(width: SeenSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ok ? s.balanceEnough : s.balanceNotEnough, style: text.bodyMedium),
                const SizedBox(height: 2),
                Wrap(spacing: SeenSpace.s4, children: [
                  Text.rich(TextSpan(style: muted, children: [
                    TextSpan(text: '${s.availableShort} '),
                    TextSpan(text: SeenFormat.isolate(SeenFormat.money(available)), style: strong),
                  ])),
                  Text.rich(TextSpan(style: muted, children: [
                    TextSpan(text: '${s.afterBooking} '),
                    TextSpan(text: SeenFormat.isolate(SeenFormat.money(available - charge)), style: strong),
                  ])),
                ]),
              ],
            ),
          ),
          if (!ok && onTopUp != null) SeenLink(label: s.topUp, onTap: onTopUp),
        ],
      ),
    );
  }
}
