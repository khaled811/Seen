// Wallet balance widgets (Figma WAL-08 states and WAL-10 breakdown): the
// breakdown card (available, held, total, credit use), the "how we compute your
// balance" legend, the over-limit card and the loading skeleton.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/wallet_balance.dart';

/// Figma WAL-10 "Balance breakdown": the available balance, how much of the
/// money is held, the total, and — when the server says how much credit is in
/// use — a bar for the credit limit. Also the hidden (WAL-08) and zero states.
class SeenBalanceBreakdownCard extends StatefulWidget {
  const SeenBalanceBreakdownCard({super.key, required this.balance, this.onTap});

  final WalletBalance balance;
  final VoidCallback? onTap;

  @override
  State<SeenBalanceBreakdownCard> createState() => _SeenBalanceBreakdownCardState();
}

class _SeenBalanceBreakdownCardState extends State<SeenBalanceBreakdownCard> {
  // Display preference only (privacy at a glance); not persisted.
  bool _hidden = false;

  static const _mask = '•••••';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final b = widget.balance;
    final glass = c.onPrimary.withAlpha(0x2E); // white @ 18%
    final fraction = b.creditUsedFraction;
    String usd(int cents) => _hidden ? '$_mask USD' : '${SeenFormat.money(cents / 100)} USD';

    Widget part(String icon, String label, String value) => Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(color: glass, borderRadius: const BorderRadius.all(SeenRadius.r14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SeenSvgIcon(icon, size: 14, color: c.onPrimary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(color: c.onPrimary.withAlpha(0xE6)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(value, textDirection: TextDirection.ltr, style: t.bodyStrong.copyWith(color: c.onPrimary)),
                ],
              ),
            ),
          ),
        );

    final String? hint = _hidden
        ? l10n.walletBalanceHiddenHint
        : b.isZero
            ? l10n.walletBalanceZeroHint
            : null;

    return Semantics(
      container: true,
      label: _hidden
          ? l10n.walletBalanceAvailableCaption
          : '${l10n.walletBalanceAvailableCaption} ${SeenFormat.money(b.availableCents / 100)} USD',
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
              onTap: widget.onTap,
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
                    padding: const EdgeInsets.all(SeenSpace.s5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            ExcludeSemantics(child: SvgPicture.asset(SeenVectors.logoWhite, width: 84, height: 42)),
                            const Spacer(),
                            Semantics(
                              button: true,
                              label: _hidden ? l10n.balanceHiddenLabel : l10n.balanceShownLabel,
                              excludeSemantics: true,
                              child: Material(
                                color: c.card,
                                shape: CircleBorder(side: BorderSide(color: c.border)),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => setState(() => _hidden = !_hidden),
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Icon(_hidden ? SeenIcons.eyeSlash : SeenIcons.eye, size: 20, color: c.primary),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(l10n.walletBalanceAvailableCaption, style: t.caption.copyWith(color: c.onPrimary.withAlpha(0xD9))),
                        const SizedBox(height: 14),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(usd(b.availableCents), textDirection: TextDirection.ltr, style: t.amountXl),
                        ),
                        if (hint != null) ...[
                          const SizedBox(height: 6),
                          Text(hint, style: t.caption.copyWith(color: c.onPrimary)),
                        ] else ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              part(SeenVectors.walletIcon, l10n.walletBalanceTotalPart, usd(b.totalCents)),
                              const SizedBox(width: 12),
                              part(SeenVectors.walletClock, l10n.walletBalanceHeldPart, usd(b.holdCents)),
                            ],
                          ),
                          if (fraction != null) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.walletCreditUsage(
                                      SeenFormat.money(b.creditUsedCents! / 100),
                                      SeenFormat.usd(b.creditLimitCents / 100),
                                    ),
                                    style: t.caption.copyWith(color: c.onPrimary.withAlpha(0xE6)),
                                  ),
                                ),
                                Text(
                                  '${(fraction * 100).round()}%',
                                  textDirection: TextDirection.ltr,
                                  style: t.caption.copyWith(color: c.onPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Semantics(
                              value: '${(fraction * 100).round()}%',
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: c.onPrimary.withAlpha(0x40),
                                  borderRadius: const BorderRadius.all(SeenRadius.full),
                                ),
                                child: SizedBox(
                                  height: 6,
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: FractionallySizedBox(
                                      widthFactor: fraction,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: c.onPrimary,
                                          borderRadius: const BorderRadius.all(Radius.circular(3)),
                                        ),
                                        child: const SizedBox(height: 6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
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

/// Figma WAL-08 "Over limit": the balance fell below the credit limit; the agent
/// has to pay the difference before new requests are accepted.
class SeenOverLimitCard extends StatelessWidget {
  const SeenOverLimitCard({super.key, required this.balance});

  final WalletBalance balance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = SeenType.of(context);
    final tone = SeenRequestStatus.rejected.colors;
    final amount = '−${SeenFormat.money(-balance.availableCents / 100)} USD';
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${l10n.walletOverLimitTitle} $amount',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: const BorderRadius.all(SeenRadius.r20),
          boxShadow: SeenShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.walletOverLimitTitle, style: t.caption.copyWith(color: tone.fg.withAlpha(0xD9))),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(amount, textDirection: TextDirection.ltr, style: t.h1.copyWith(color: tone.fg)),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.walletOverLimitHint(SeenFormat.usd(balance.overLimitCents / 100)),
                style: t.caption.copyWith(color: tone.fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma WAL-10 "How we calculate your balance": what each figure means.
class SeenBalanceLegendCard extends StatelessWidget {
  const SeenBalanceLegendCard({super.key, required this.showCredit});

  /// Credit is only explained when the agent has a credit limit.
  final bool showCredit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);

    Widget item(SeenRequestStatus chip, String chipLabel, String title, String body) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SeenStatusChip(status: chip, label: chipLabel),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.label.copyWith(color: c.ink)),
                  Text(body, style: t.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ],
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.walletLegendTitle, style: t.title.copyWith(color: c.ink)),
            const SizedBox(height: 10),
            item(SeenRequestStatus.completed, l10n.walletLegendAvailable, l10n.walletLegendAvailable,
                l10n.walletLegendAvailableBody),
            const SizedBox(height: 10),
            item(SeenRequestStatus.actionRequired, l10n.walletChipHeld, l10n.walletChipHeld, l10n.walletLegendHeldBody),
            if (showCredit) ...[
              const SizedBox(height: 10),
              item(SeenRequestStatus.underReview, l10n.walletLegendCredit, l10n.walletLegendCredit,
                  l10n.walletLegendCreditBody),
            ],
          ],
        ),
      ),
    );
  }
}

/// Figma WAL-08 "Loading": the balance card's skeleton, then ledger rows.
class WalletLoadingSkeleton extends StatelessWidget {
  const WalletLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h, double r) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [Color(0xFFEFEBF8), Color(0xFFF7F5FC)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(r)),
          ),
          child: SizedBox(width: w, height: h),
        );
    return Semantics(
      label: AppLocalizations.of(context)!.loading,
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: SeenBrand.violet05, borderRadius: BorderRadius.all(SeenRadius.r20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [bar(120, 10, 5), const SizedBox(height: 8), bar(200, 24, 8)],
                ),
              ),
            ),
            for (var i = 0; i < 4; i++) ...[
              const SizedBox(height: 12),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Color(0xFFEFEBF8), Color(0xFFF7F5FC)],
                  ),
                  borderRadius: BorderRadius.all(SeenRadius.r18),
                ),
                child: SizedBox(height: 64),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
