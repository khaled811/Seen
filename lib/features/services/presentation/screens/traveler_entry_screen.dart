import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../dynamic_forms/presentation/widgets/dynamic_field_widget.dart';
import '../bloc/service_booking_bloc.dart';
import '../bloc/service_booking_event.dart';
import '../bloc/service_booking_state.dart';
import '../widgets/seen_traveler_chips.dart';
import '../widgets/seen_validity_hint.dart';
import 'booking_review_screen.dart';

const _passportExpiryFieldKey = 'passportExpiryDate';

/// Bulk/multi-passenger traveler entry: a chip per traveler (add/remove),
/// with the active traveler's fields rendered via the Task 05 dynamic form
/// engine (`DynamicFieldWidget`) — reused as-is, not reimplemented. Only the
/// chrome around it (chips, spacing, continue bar) is design-system-skinned;
/// `DynamicFieldWidget` is a shared, feature-agnostic engine (also used by
/// the Forms Gallery) with no Seen equivalent for its date/select inputs, so
/// it stays untouched rather than risk a wider regression.
class TravelerEntryScreen extends StatelessWidget {
  const TravelerEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<ServiceBookingBloc, ServiceBookingState>(
      listenWhen: (previous, current) =>
          current is ServiceBookingInProgress && current.reviewReady,
      listener: (context, state) {
        final bloc = context.read<ServiceBookingBloc>()
          ..add(const ReviewReadyAcknowledged());
        // Same reason as ServiceSelectionScreen's push: forward the same
        // Bloc instance explicitly, since the pushed route isn't a
        // descendant of this screen's BlocProvider.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: bloc,
              child: const BookingReviewScreen(),
            ),
          ),
        );
      },
      child: Scaffold(
        appBar: SeenTopBar.inner(title: l10n.travelerEntryTitle),
        body: BlocBuilder<ServiceBookingBloc, ServiceBookingState>(
          builder: (context, state) {
            if (state is! ServiceBookingInProgress) {
              return const Center(child: SeenLoader());
            }
            return Column(
              children: [
                const SizedBox(height: SeenSpace.s2),
                _TravelerTabs(state: state),
                const SizedBox(height: SeenSpace.s2),
                Expanded(child: _TravelerForm(state: state)),
                _ContinueBar(state: state),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TravelerTabs extends StatelessWidget {
  const _TravelerTabs({required this.state});

  final ServiceBookingInProgress state;

  @override
  Widget build(BuildContext context) {
    return SeenTravelerChips(
      travelers: [
        for (final traveler in state.travelers)
          SeenTravelerChipData(
            state: (state.travelerErrors[traveler.id]?.isNotEmpty ?? false)
                ? SeenTravelerState.error
                : (traveler.fieldValues.isNotEmpty ? SeenTravelerState.done : SeenTravelerState.empty),
          ),
      ],
      activeIndex: state.activeTravelerIndex,
      onSelected: (i) => context.read<ServiceBookingBloc>().add(ActiveTravelerChanged(i)),
      onAdd: () => context.read<ServiceBookingBloc>().add(const TravelerAdded()),
    );
  }
}

class _TravelerForm extends StatelessWidget {
  const _TravelerForm({required this.state});

  final ServiceBookingInProgress state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final traveler = state.activeTraveler;
    final errors = state.travelerErrors[traveler.id] ?? const {};
    final expiry = traveler.fieldValues[_passportExpiryFieldKey];
    return ListView(
      padding: const EdgeInsets.all(SeenSpace.s4),
      // Re-key per traveler so each `DynamicFieldWidget`'s internal
      // `TextEditingController` resets to that traveler's own values
      // instead of carrying over the previous traveler's text.
      key: ValueKey(traveler.id),
      children: [
        for (final field in state.travelerFields) ...[
          DynamicFieldWidget(
            key: ValueKey('${traveler.id}-${field.key}'),
            field: field,
            value: traveler.fieldValues[field.key],
            errorText: errors[field.key],
            onChanged: (value) => context.read<ServiceBookingBloc>().add(
                  TravelerFieldChanged(
                    travelerIndex: state.activeTravelerIndex,
                    fieldKey: field.key,
                    value: value,
                  ),
                ),
          ),
          if (field.key == _passportExpiryFieldKey && expiry is DateTime)
            SeenValidityHint.fromDates(expiry: expiry, travelDate: DateTime.now()),
        ],
        const SizedBox(height: SeenSpace.s2),
        // Mocked/decoupled, same treatment as the wallet top-up receipt row.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.badge_outlined),
          title: Text(l10n.travelerAttachmentLabel),
          subtitle: Text(l10n.attachmentComingSoon),
          enabled: false,
        ),
        if (state.travelers.length > 1) ...[
          const SizedBox(height: SeenSpace.s2),
          SeenButton.dangerOutline(
            label: l10n.removeTravelerAction,
            expand: true,
            onPressed: () =>
                context.read<ServiceBookingBloc>().add(TravelerRemoved(state.activeTravelerIndex)),
          ),
        ],
      ],
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.state});

  final ServiceBookingInProgress state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SeenActionBar(
      actions: [
        SeenButton(
          label: l10n.continueToReviewAction,
          expand: true,
          onPressed: () => context.read<ServiceBookingBloc>().add(const TravelerContinuePressed()),
        ),
      ],
    );
  }
}
