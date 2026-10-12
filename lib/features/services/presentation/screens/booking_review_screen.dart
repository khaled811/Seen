import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/balance_banner.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../bloc/service_booking_bloc.dart';
import '../bloc/service_booking_event.dart';
import '../bloc/service_booking_state.dart';
import '../widgets/seen_breakdown_table.dart';
import 'booking_success_screen.dart';

/// Cost breakdown + wallet balance + final confirmation — where the Dynamic
/// Form Engine's captured travelers meet the Wallet feature's balance data.
class BookingReviewScreen extends StatelessWidget {
  const BookingReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            final requestId = (state as ServiceBookingInProgress).submissionResult?.requestId ?? '';
            // Terminal screen — replace rather than push, so the completed
            // form can't be navigated back into.
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => BookingSuccessScreen(requestId: requestId)),
            );
          },
        ),
      ],
      child: Scaffold(
        appBar: SeenTopBar.inner(title: l10n.reviewTitle),
        body: BlocBuilder<ServiceBookingBloc, ServiceBookingState>(
          builder: (context, state) {
            if (state is! ServiceBookingInProgress) {
              return const Center(child: SeenLoader());
            }
            return _ReviewBody(state: state);
          },
        ),
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.state});

  final ServiceBookingInProgress state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSubmitting = state.submissionStatus == BookingSubmissionStatus.submitting;
    final totalPrice = state.totalPriceCents / 100;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(SeenSpace.s4),
              children: [
                SeenBreakdownTable(rows: [
                  SeenBreakdownRow(
                    label: state.service.name,
                    caption: l10n.requestCardTravelersLabel(state.travelers.length),
                    unitPrice: state.service.perPersonPriceCents / 100,
                    quantity: state.travelers.length,
                  ),
                ]),
                const SizedBox(height: SeenSpace.s4),
                state.walletBalanceLoading
                    ? const Center(child: SeenLoader())
                    : SeenBalanceBanner(
                        available: (state.walletBalance?.availableCents ?? 0) / 100,
                        charge: totalPrice,
                      ),
              ],
            ),
          ),
          SeenActionBar(
            actions: [
              SeenButton(
                label: isSubmitting ? l10n.loading : l10n.reviewSubmitHoldAction(SeenFormat.usd(totalPrice)),
                expand: true,
                onPressed:
                    isSubmitting ? null : () => context.read<ServiceBookingBloc>().add(const BookingSubmitted()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
