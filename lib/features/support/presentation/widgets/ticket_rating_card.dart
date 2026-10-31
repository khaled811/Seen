// The rating card at the end of a resolved or closed ticket (design/gaps SUP-06): the person
// picks 1-5 stars and sends once; afterwards the stars are locked. The server takes no comment.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/rating_stars.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../bloc/ticket_rating_cubit.dart';

class TicketRatingCard extends StatelessWidget {
  const TicketRatingCard({super.key});

  static String _word(AppLocalizations l10n, int stars) => switch (stars) {
        1 => l10n.supStar1,
        2 => l10n.supStar2,
        3 => l10n.supStar3,
        4 => l10n.supStar4,
        5 => l10n.supStar5,
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return BlocBuilder<TicketRatingCubit, TicketRatingState>(
      builder: (context, state) {
        final cubit = context.read<TicketRatingCubit>();
        final failed = state.issue != null;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.border),
            borderRadius: const BorderRadius.all(SeenRadius.r22),
            boxShadow: SeenShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(state.done ? l10n.supRatedTitle : l10n.supRateTitle, style: type.title, textAlign: TextAlign.center),
                if (!state.done) ...[
                  const SizedBox(height: 4),
                  Text(l10n.supRateSub, style: type.caption.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 12),
                RatingStars(
                  value: state.stars,
                  mode: state.done
                      ? RatingMode.locked
                      : (state.sending ? RatingMode.readonly : RatingMode.input),
                  onChanged: cubit.select,
                  groupLabel: l10n.supRateA11y,
                  starLabel: (v) => l10n.supStarA11y(v),
                ),
                if (state.stars > 0) ...[
                  const SizedBox(height: 6),
                  Text(_word(l10n, state.stars), style: type.label.copyWith(color: c.inkSecondary)),
                ],
                if (state.stars > 0 && !state.done) ...[
                  const SizedBox(height: 12),
                  if (failed) ...[
                    SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.supRateFailed),
                    const SizedBox(height: 10),
                  ],
                  SeenButton(
                    label: state.sending ? l10n.supSending : (failed ? l10n.commonRetry : l10n.supSendRating),
                    icon: failed && !state.sending ? SeenIcons.refresh : null,
                    size: SeenButtonSize.small,
                    loading: state.sending,
                    onPressed: state.sending ? null : cubit.submit,
                  ),
                ],
                if (state.done) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(SeenIcons.check, size: 14, color: SeenRequestStatus.completed.colors.fg),
                      const SizedBox(width: 6),
                      Text(l10n.supThanks, style: type.label.copyWith(color: SeenRequestStatus.completed.colors.fg)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(l10n.supRatedLocked, style: type.caption.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
