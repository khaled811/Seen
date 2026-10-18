import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/screens/top_up_request_screen.dart';
import '../bloc/service_booking_bloc.dart';
import '../bloc/service_booking_event.dart';
import '../bloc/service_booking_state.dart';
import '../widgets/seen_booking_review_cards.dart';
import '../widgets/service_card_copy.dart';
import 'booking_success_screen.dart';

const _gutter = 20.0;

/// Booking review (Figma 10, step 3 of 3): service, travelers, fees, the
/// wallet hold, an explicit confirmation, and the final submit — where the
/// captured travelers meet the wallet balance. Submission, the success
/// navigation and the debug-fallback data sources are unchanged.
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
              current.submissionStatus == BookingSubmissionStatus.failure,
          listener: (context, state) {
            final message = (state as ServiceBookingInProgress).submissionError ?? l10n.error;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
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
            final held = result?.totalPriceCents ?? booking.totalPriceCents;
            final balance = booking.walletBalance;
            // Terminal screen — replace rather than push, so the completed
            // form can't be navigated back into.
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BookingSuccessScreen(
                  requestId: result?.requestId ?? '',
                  serviceName: booking.service.name,
                  travelerCount: booking.travelers.length,
                  heldCents: held,
                  balanceAfterCents: balance == null ? null : balance.availableCents - held,
                ),
              ),
            );
          },
        ),
      ],
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
                    Expanded(child: _ReviewBody(state: state)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewBody extends StatefulWidget {
  const _ReviewBody({required this.state});

  final ServiceBookingInProgress state;

  @override
  State<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends State<_ReviewBody> {
  // UI-only acknowledgement that gates the submit button; the booking bloc
  // and the backend contract do not know about it.
  bool _confirmed = false;

  /// Opens the top-up form for [shortfallCents] and reloads the balance when the
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
    bloc.add(const BookingBalanceRefreshRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final type = SeenType.of(context);
    final state = widget.state;
    final isSubmitting = state.submissionStatus == BookingSubmissionStatus.submitting;
    final totalPrice = state.totalPriceCents / 100;
    final facts = ServiceCardCopy.forCategory(state.service.category, l10n);
    final balance = state.walletBalance;
    final insufficient = !state.hasSufficientBalance;

    final travelers = [
      for (final t in state.travelers)
        SeenReviewTraveler(
          name: (t.fieldValues['fullName'] as String?)?.trim().isNotEmpty == true
              ? (t.fieldValues['fullName'] as String).trim()
              : '—',
          passport: t.fieldValues['passportNumber'] as String?,
        ),
    ];

    // Navigator captured up front: the editing buttons pop routes.
    final navigator = Navigator.of(context);

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
                title: state.service.name,
                subtitle: state.hospital != null
                    ? '${s.travelerCount(state.travelers.length)} · ${state.hospital!.name}'
                    : '${s.travelerCount(state.travelers.length)} · ${facts.processing}',
                editLabel: l10n.reviewEditAction,
                // Back to the catalog: this review and the traveler form both pop.
                onEdit: () {
                  navigator.pop();
                  navigator.pop();
                },
              ),
              sectionHeader(l10n.requestDetailTravelersSection, onEdit: () => navigator.pop()),
              SeenReviewTravelersCard(travelers: travelers),
              sectionHeader(l10n.reviewFeesSection),
              SeenReviewFeesCard(
                travelerCount: state.travelers.length,
                perTravelerPrice: state.service.perPersonPriceCents / 100,
                totalLabel: l10n.reviewTotal,
              ),
              const SizedBox(height: 18),
              if (insufficient && balance != null) ...[
                // Figma BOOK-08: the balance does not cover it: say by how much and
                // offer the top-up for exactly that.
                SeenShortfallCard(
                  title: s.balanceNotEnough,
                  available: balance.availableCents / 100,
                  availableLabel: l10n.reviewShortfallAvailable,
                  creditRemaining: balance.creditRemainingCents == null ? null : balance.creditRemainingCents! / 100,
                  creditLabel: l10n.reviewShortfallCredit,
                  shortfall: state.shortfallCents / 100,
                  shortfallLabel: l10n.reviewShortfallMissing,
                ),
                const SizedBox(height: 14),
                SeenButton.secondary(
                  label: l10n.reviewTopUpShortfall(SeenFormat.usd(state.shortfallCents / 100)),
                  expand: true,
                  onPressed: () => _topUp(context, state.shortfallCents),
                ),
              ] else ...[
                SeenWalletHoldCard(
                  charge: totalPrice,
                  available: balance == null ? null : balance.availableCents / 100,
                  loading: state.walletBalanceLoading,
                  titleBuilder: l10n.reviewHoldTitle,
                  note: l10n.reviewHoldNote,
                  afterLabel: l10n.reviewAvailableAfter,
                ),
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
              // The reason it is disabled is on screen: the confirmation row above.
              onPressed: _confirmed && !insufficient
                  ? () => context.read<ServiceBookingBloc>().add(const BookingSubmitted())
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
