import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/presentation/widgets/loading/seen_blocking_overlay.dart';
import '../../../../core/presentation/widgets/loading/loading_strings.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/screens/top_up_request_screen.dart';
import '../../domain/entities/draft_review.dart';
import '../bloc/service_booking_bloc.dart';
import '../bloc/service_booking_event.dart';
import '../bloc/service_booking_state.dart';
import '../widgets/seen_booking_review_cards.dart';
import '../widgets/service_card_copy.dart';
import 'booking_success_screen.dart';

const _gutter = 20.0;

/// Booking review (Figma 10, step 3 of 3): service, travelers, fees, the
/// wallet hold, an explicit confirmation, and the final submit. Everything
/// shown here is the server's own quote (`portalDraftReview`); the app computes
/// no price and no balance verdict, and the server's `canSubmit` gates the
/// button.
class BookingReviewScreen extends StatelessWidget {
  const BookingReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<ServiceBookingBloc, ServiceBookingState>(
          listenWhen: (previous, current) =>
              current is ServiceBookingInProgress &&
              current.submissionStatus == BookingSubmissionStatus.failure &&
              (previous is! ServiceBookingInProgress || previous.submissionStatus != BookingSubmissionStatus.failure),
          listener: (context, state) {
            final failure = (state as ServiceBookingInProgress).submissionFailure;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(failureTextOr(l10n, failure, l10n.error))));
            // The quote may be out of date (the balance changed, the draft moved on).
            context.read<ServiceBookingBloc>().add(const BookingReviewRefreshRequested());
          },
        ),
        BlocListener<ServiceBookingBloc, ServiceBookingState>(
          listenWhen: (previous, current) =>
              previous is ServiceBookingInProgress &&
              previous.submissionStatus != BookingSubmissionStatus.success &&
              current is ServiceBookingInProgress &&
              current.submissionStatus == BookingSubmissionStatus.success,
          listener: (context, state) {
            final booking = state as ServiceBookingInProgress;
            final result = booking.submissionResult;
            final quote = booking.review?.quote;
            // Terminal screen — replace rather than push, so the completed
            // form can't be navigated back into.
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BookingSuccessScreen(
                  requestId: result?.requestId ?? '',
                  referenceCode: result?.hasReference == true ? result!.referenceCode : null,
                  serviceName: booking.review?.serviceName ?? booking.service.name,
                  travelerCount: booking.review?.travelers.length ?? booking.travelers.length,
                  // Nothing is held at submit when the service waits for approval.
                  heldCents: quote == null || quote.holdDeferred ? null : quote.totalCents,
                  balanceAfterCents: quote == null || quote.holdDeferred ? null : quote.availableAfterCents,
                  holdDeferred: quote?.holdDeferred ?? false,
                ),
              ),
            );
          },
        ),
      ],
      child: BlocSelector<ServiceBookingBloc, ServiceBookingState, bool>(
        selector: (state) =>
            state is ServiceBookingInProgress && state.submissionStatus == BookingSubmissionStatus.submitting,
        builder: (context, submitting) => SeenBlockingOverlay(
          visible: submitting,
          title: SeenStrings.of(context).submittingRequest,
          child: Scaffold(
        backgroundColor: c.card,
        body: SeenScreenBackground(
          child: SafeArea(
            bottom: false,
            child: BlocBuilder<ServiceBookingBloc, ServiceBookingState>(
              builder: (context, state) {
                if (state is! ServiceBookingInProgress) return const Center(child: SeenLoader());
                return Column(
                  children: [
                    SeenScreenHeader(title: l10n.reviewTitle, subtitle: SeenStrings.of(context).bookingStep(3, 3)),
                    Expanded(child: _ReviewContent(state: state)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
    ),
    );
  }
}

/// The review once it is loaded; a spinner while loading; a retry when it failed.
class _ReviewContent extends StatelessWidget {
  const _ReviewContent({required this.state});

  final ServiceBookingInProgress state;

  @override
  Widget build(BuildContext context) {
    final review = state.review;
    if (review != null) return _ReviewBody(state: state, review: review);
    final l10n = AppLocalizations.of(context)!;
    if (state.reviewFailure != null && !state.reviewLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(_gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(failureTextOr(l10n, state.reviewFailure, l10n.reviewLoadFailed), textAlign: TextAlign.center),
              const SizedBox(height: SeenSpace.s3),
              SeenButton(
                label: l10n.retry,
                onPressed: () => context.read<ServiceBookingBloc>().add(const BookingReviewRefreshRequested()),
              ),
            ],
          ),
        ),
      );
    }
    return const Center(child: SeenLoader());
  }
}

class _ReviewBody extends StatefulWidget {
  const _ReviewBody({required this.state, required this.review});

  final ServiceBookingInProgress state;
  final DraftReview review;

  @override
  State<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends State<_ReviewBody> {
  // UI-only acknowledgement that gates the submit button; the booking bloc
  // and the backend contract do not know about it.
  bool _confirmed = false;

  /// Opens the top-up form for [shortfallCents] and reloads the quote when the
  /// agent comes back (the form's own wallet bloc lives only for that route).
  Future<void> _topUp(BuildContext context, int shortfallCents) async {
    final bloc = context.read<ServiceBookingBloc>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => InjectionContainer.instance.createWalletBloc()..add(const WalletLoadRequested()),
          child: TopUpRequestScreen(
            prefill: TopUpPrefill(amountCents: shortfallCents, method: TopUpMethod.bankTransfer),
          ),
        ),
      ),
    );
    bloc.add(const BookingReviewRefreshRequested());
  }

  /// What is missing to pay for the request, from the server's own figures:
  /// the shortfall it reports after the hold, else the total minus the balance.
  static int _shortfallCents(ReviewQuote quote) {
    final after = quote.availableAfterCents;
    if (after != null && after < 0) return -after;
    final missing = (quote.totalCents ?? 0) - (quote.balanceCents ?? 0);
    return missing > 0 ? missing : (quote.totalCents ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final type = SeenType.of(context);
    final state = widget.state;
    final review = widget.review;
    final quote = review.quote;
    final isSubmitting = state.submissionStatus == BookingSubmissionStatus.submitting;
    final facts = ServiceCardCopy.forCategory(state.service.category, l10n);
    final count = review.travelers.length;
    final total = quote.totalCents;
    final balance = quote.balanceCents;
    final insufficient = !quote.holdDeferred && quote.fundsSufficient == false;
    final shortfall = _shortfallCents(quote);

    final travelers = [
      for (final t in review.travelers)
        SeenReviewTraveler(
          name: (t.name ?? '').trim().isNotEmpty ? t.name!.trim() : '—',
          passport: t.passportNumber,
        ),
    ];

    // Navigator captured up front: the editing buttons pop routes. A draft opened
    // from the list cannot be edited (the server has no way to change a traveler).
    final navigator = Navigator.of(context);
    final canEdit = !state.resumed;

    Widget sectionHeader(String title, {VoidCallback? onEdit}) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 18),
          child: Row(
            children: [
              Expanded(child: Text(title, style: type.h2)),
              if (onEdit != null) SeenTextLink(label: l10n.reviewEditAction, onTap: onEdit),
            ],
          ),
        );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s1, _gutter, SeenSpace.s5),
            children: [
              SeenReviewServiceCard(
                iconAsset: facts.iconAsset,
                title: review.serviceName,
                subtitle: state.hospital != null
                    ? '${s.travelerCount(count)} · ${state.hospital!.name}'
                    : '${s.travelerCount(count)} · ${facts.processing}',
                editLabel: l10n.reviewEditAction,
                // Back to the catalog: this review and the traveler form both pop.
                onEdit: canEdit
                    ? () {
                        navigator.pop();
                        navigator.pop();
                      }
                    : null,
              ),
              sectionHeader(l10n.requestDetailTravelersSection, onEdit: canEdit ? () => navigator.pop() : null),
              SeenReviewTravelersCard(travelers: travelers),
              sectionHeader(l10n.reviewFeesSection),
              SeenReviewFeesCard(
                travelerCount: quote.travelerCount,
                perTravelerPrice: (quote.unitPriceCents ?? 0) / 100,
                total: total == null ? null : total / 100,
                totalLabel: l10n.reviewTotal,
              ),
              const SizedBox(height: 18),
              if (quote.holdDeferred)
                // Contract section 9: the fee is held after approval, not now.
                SeenInlineBanner(tone: SeenBannerTone.info, message: l10n.reviewHoldDeferredNote)
              else if (insufficient && balance != null) ...[
                // Figma BOOK-08: the balance does not cover it: say by how much and
                // offer the top-up for exactly that.
                SeenShortfallCard(
                  title: s.balanceNotEnough,
                  available: balance / 100,
                  availableLabel: l10n.reviewShortfallAvailable,
                  shortfall: shortfall / 100,
                  shortfallLabel: l10n.reviewShortfallMissing,
                ),
                const SizedBox(height: 14),
                SeenButton.secondary(
                  label: l10n.reviewTopUpShortfall(SeenFormat.usd(shortfall / 100)),
                  expand: true,
                  onPressed: () => _topUp(context, shortfall),
                ),
              ] else if (total != null) ...[
                SeenWalletHoldCard(
                  charge: total / 100,
                  available: balance == null ? null : balance / 100,
                  loading: state.reviewLoading,
                  titleBuilder: l10n.reviewHoldTitle,
                  note: l10n.reviewHoldNote,
                  afterLabel: l10n.reviewAvailableAfter,
                ),
              ],
              if (!review.canSubmit && !insufficient) ...[
                const SizedBox(height: 14),
                SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.reviewCannotSubmit),
              ],
              if (!insufficient) ...[
                const SizedBox(height: 18),
                SeenConfirmCheck(
                  value: _confirmed,
                  label: l10n.reviewConfirmTerms,
                  onChanged: (v) => setState(() => _confirmed = v),
                ),
              ],
            ],
          ),
        ),
        SeenActionBar(
          actions: [
            SeenButton(
              label: isSubmitting ? l10n.loading : l10n.reviewSubmitAction,
              expand: true,
              loading: isSubmitting,
              // The reason it is disabled is on screen: the confirmation row or the banner above.
              onPressed: _confirmed && review.canSubmit && !insufficient && !isSubmitting
                  ? () => context.read<ServiceBookingBloc>().add(const BookingSubmitted())
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
