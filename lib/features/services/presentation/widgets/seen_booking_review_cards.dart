// Booking review building blocks (Figma 10): service summary, travelers list,
// fee breakdown, wallet-hold panel and the confirmation checkbox. Presentation
// only: amounts and counts are passed in; nothing here talks to the bloc.
import 'package:flutter/material.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

DecoratedBox _card(SeenColors c, Widget child, {Gradient? gradient}) => DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? c.card : null,
        gradient: gradient,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: gradient == null ? SeenShadows.card : null,
      ),
      child: child,
    );

/// Service name + one-line meta (travelers · processing time) with an Edit pill.
class SeenReviewServiceCard extends StatelessWidget {
  const SeenReviewServiceCard({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.editLabel,
    this.onEdit,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final String editLabel;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return _card(
      c,
      Padding(
        padding: const EdgeInsets.all(SeenSpace.s4),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: c.primarySoft, borderRadius: const BorderRadius.all(SeenRadius.r14)),
              child: SizedBox(width: 48, height: 48, child: Center(child: SeenSvgIcon(iconAsset, size: 26))),
            ),
            const SizedBox(width: SeenSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: type.title),
                  Text(subtitle, style: type.caption.copyWith(color: c.inkSecondary)),
                ],
              ),
            ),
            if (onEdit != null) ...[
              const SizedBox(width: SeenSpace.s3),
              SeenButton.outline(label: editLabel, size: SeenButtonSize.extraSmall, onPressed: onEdit),
            ],
          ],
        ),
      ),
    );
  }
}

class SeenReviewTraveler {
  const SeenReviewTraveler({required this.name, this.passport});

  final String name;
  final String? passport;
}

/// Numbered traveler rows: name and passport number.
class SeenReviewTravelersCard extends StatelessWidget {
  const SeenReviewTravelersCard({super.key, required this.travelers});

  final List<SeenReviewTraveler> travelers;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final s = SeenStrings.of(context);
    return _card(
      c,
      Column(
        children: [
          for (var i = 0; i < travelers.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: 14),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(child: Text(s.numeral(i + 1), style: type.label.copyWith(color: c.primary))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(travelers[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: type.body)),
                  if (travelers[i].passport != null && travelers[i].passport!.isNotEmpty)
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        travelers[i].passport!,
                        style: type.label.copyWith(color: c.inkMuted, fontFeatures: SeenFonts.tabular),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fee breakdown: "service fee × n" line and the total, in the Figma fees card.
/// Only data the app has is shown (no authority-fee or margin rows: the API
/// exposes a single per-traveler price).
class SeenReviewFeesCard extends StatelessWidget {
  const SeenReviewFeesCard({
    super.key,
    required this.travelerCount,
    required this.perTravelerPrice,
    required this.totalLabel,
  });

  final int travelerCount;
  final num perTravelerPrice;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final s = SeenStrings.of(context);
    final total = perTravelerPrice * travelerCount;
    return _card(
      c,
      Padding(
        padding: const EdgeInsets.all(SeenSpace.s4),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(s.serviceFeeTimes(travelerCount), style: type.body.copyWith(color: c.inkSecondary))),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '$travelerCount × ${SeenFormat.money(perTravelerPrice)} USD',
                    style: type.bodyStrong.copyWith(fontFeatures: SeenFonts.tabular),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SeenSpace.s3),
            Divider(height: 1, thickness: 1, color: c.border),
            const SizedBox(height: SeenSpace.s3),
            Row(
              children: [
                Expanded(child: Text(totalLabel, style: type.body.copyWith(color: c.inkSecondary))),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${SeenFormat.money(total)} USD',
                    style: type.h2.copyWith(color: SeenBrand.violet, fontFeatures: SeenFonts.tabular),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "X will be held from your balance" panel: how much of the balance the
/// booking takes, and what is left. Flags an insufficient balance (UX aid only;
/// the backend enforces).
class SeenWalletHoldCard extends StatelessWidget {
  const SeenWalletHoldCard({
    super.key,
    required this.charge,
    required this.available,
    required this.loading,
    required this.titleBuilder,
    required this.note,
    required this.afterLabel,
  });

  final num charge;

  /// null while unknown.
  final num? available;
  final bool loading;
  final String Function(String amount) titleBuilder;
  final String note;
  final String afterLabel;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final s = SeenStrings.of(context);
    final left = available == null ? null : available! - charge;
    final insufficient = left != null && left < 0;
    final fraction = available == null || available! <= 0 ? 1.0 : (charge / available!).clamp(0.0, 1.0).toDouble();

    return _card(
      c,
      gradient: SeenBrand.gradientWalletHold,
      ClipRRect(
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        child: Stack(
          children: [
            Positioned(
              left: -151,
              top: -111,
              width: 304.8,
              height: 218.4,
              child: ExcludeSemantics(
                child: SvgPicture.asset(SeenVectors.reviewPatternIsometric, fit: BoxFit.fill),
              ),
            ),
            Padding(
        padding: const EdgeInsets.all(SeenSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: c.card, borderRadius: const BorderRadius.all(SeenRadius.r12)),
                  child: const SizedBox(width: 40, height: 40, child: Center(child: SeenSvgIcon(SeenVectors.reviewWallet, size: 22))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titleBuilder(SeenFormat.usd(charge)), style: type.bodyStrong),
                      Text(note, style: type.caption.copyWith(color: c.inkSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: SeenSpace.s2), child: Center(child: SeenLoader()))
            else if (available != null) ...[
              DecoratedBox(
                decoration: BoxDecoration(color: c.card, borderRadius: const BorderRadius.all(SeenRadius.full)),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: fraction,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: insufficient ? null : SeenBrand.gradientCta,
                        color: insufficient ? c.dangerFg : null,
                        borderRadius: const BorderRadius.all(Radius.circular(3)),
                      ),
                      child: const SizedBox(height: 6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      insufficient ? s.balanceNotEnough : afterLabel,
                      style: type.body.copyWith(color: insufficient ? c.dangerFg : c.inkSecondary),
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${SeenFormat.money(left!)} USD',
                      style: type.bodyStrong.copyWith(
                        color: insufficient ? c.dangerFg : c.ink,
                        fontFeatures: SeenFonts.tabular,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
          ],
        ),
      ),
    );
  }
}

/// Figma "Terms" row: a violet checkbox with its confirmation text.
class SeenConfirmCheck extends StatelessWidget {
  const SeenConfirmCheck({super.key, required this.value, required this.label, required this.onChanged});

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Semantics(
      checked: value,
      inMutuallyExclusiveGroup: false,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: const BorderRadius.all(SeenRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SeenSize.touchMin),
          child: Row(
            children: [
              // Checked: the exported Figma checkbox (gradient with a white tick).
              value
                  ? SvgPicture.asset(SeenVectors.reviewCheckboxChecked, width: 22, height: 22, excludeFromSemantics: true)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: const BorderRadius.all(Radius.circular(6)),
                        border: Border.all(color: c.borderStrong, width: 1.5),
                      ),
                      child: const SizedBox(width: 22, height: 22),
                    ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: type.label.copyWith(color: c.inkSecondary))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma BOOK-08: the balance does not cover the booking. The numbers behind the
/// shortfall: what is available, the credit still free, and what is missing.
class SeenShortfallCard extends StatelessWidget {
  const SeenShortfallCard({
    super.key,
    required this.title,
    required this.available,
    required this.availableLabel,
    required this.shortfall,
    required this.shortfallLabel,
    this.creditRemaining,
    this.creditLabel,
  });

  final String title;
  final num available;
  final String availableLabel;
  final num shortfall;
  final String shortfallLabel;

  /// Shown only when the server says how much credit is free.
  final num? creditRemaining;
  final String? creditLabel;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final tone = SeenRequestStatus.rejected.colors;
    Widget row(String label, num amount) => Row(
          children: [
            Text(label, style: type.body.copyWith(color: c.inkSecondary)),
            const Spacer(),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text('${SeenFormat.money(amount)} USD', style: type.bodyStrong.copyWith(color: tone.fg)),
            ),
          ],
        );
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: tone.bg, borderRadius: const BorderRadius.all(SeenRadius.r20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(SeenIcons.alert, size: 20, color: tone.fg),
                  const SizedBox(width: 8),
                  Text(title, style: type.title.copyWith(color: tone.fg)),
                ],
              ),
              const SizedBox(height: 10),
              row(availableLabel, available),
              if (creditRemaining != null && creditLabel != null) ...[
                const SizedBox(height: 10),
                row(creditLabel!, creditRemaining!),
              ],
              const SizedBox(height: 10),
              row(shortfallLabel, shortfall),
            ],
          ),
        ),
      ),
    );
  }
}
