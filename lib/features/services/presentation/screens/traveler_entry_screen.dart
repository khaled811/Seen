import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/dropzone.dart';
import '../../../../core/presentation/widgets/form_stepper.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';
import '../../domain/entities/traveler_info.dart';
import '../bloc/service_booking_bloc.dart';
import '../bloc/service_booking_event.dart';
import '../bloc/service_booking_state.dart';
import '../widgets/seen_dynamic_field.dart';
import '../widgets/seen_traveler_chips.dart';
import '../widgets/seen_validity_hint.dart';
import 'booking_review_screen.dart';

const _passportExpiryFieldKey = 'passportExpiryDate';
const _gutter = 20.0;

/// Fields whose value is a Latin-script run (passport data).
const _ltrFieldKeys = {'passportNumber'};

/// Traveler entry (Figma 09, step 2 of 3): form stepper, a chip per traveler
/// (add / remove), and the active traveler's fields as a card. Fields come
/// from the same `DynamicFormField` definitions as before, rendered by
/// [SeenDynamicField]; validation and the booking bloc are unchanged.
class TravelerEntryScreen extends StatelessWidget {
  const TravelerEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return BlocListener<ServiceBookingBloc, ServiceBookingState>(
      listenWhen: (previous, current) => current is ServiceBookingInProgress && current.reviewReady,
      listener: (context, state) {
        final bloc = context.read<ServiceBookingBloc>()..add(const ReviewReadyAcknowledged());
        // Same reason as ServiceSelectionScreen's push: forward the same
        // Bloc instance explicitly, since the pushed route isn't a
        // descendant of this screen's BlocProvider.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(value: bloc, child: const BookingReviewScreen()),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: c.card,
        body: SeenScreenBackground(
          child: SafeArea(
            bottom: false,
            child: BlocBuilder<ServiceBookingBloc, ServiceBookingState>(
              builder: (context, state) {
                if (state is! ServiceBookingInProgress) return const Center(child: SeenLoader());
                final s = SeenStrings.of(context);
                return Column(
                  children: [
                    SeenScreenHeader(title: state.service.name, subtitle: s.bookingStep(2, 3)),
                    Expanded(child: _Body(state: state)),
                  ],
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: BlocBuilder<ServiceBookingBloc, ServiceBookingState>(
          buildWhen: (previous, current) => (previous is ServiceBookingInProgress) != (current is ServiceBookingInProgress),
          builder: (context, state) {
            if (state is! ServiceBookingInProgress) return const SizedBox.shrink();
            return const _ActionsBar();
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final ServiceBookingInProgress state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final traveler = state.activeTraveler;
    return ListView(
      padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s1, _gutter, SeenSpace.s6),
      children: [
        SeenFormStepper(
          labels: [l10n.bookingStepService, l10n.bookingStepTravelers, l10n.bookingStepReview],
          current: 1,
        ),
        const SizedBox(height: SeenSpace.s4),
        _TravelerTabs(state: state),
        const SizedBox(height: SeenSpace.s3),
        // A fresh card per traveler, cross-faded (add / remove / switch).
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey(traveler.id),
              child: _TravelerCard(state: state),
            ),
          ),
        ),
      ],
    );
  }
}

class _TravelerTabs extends StatelessWidget {
  const _TravelerTabs({required this.state});

  final ServiceBookingInProgress state;

  @override
  Widget build(BuildContext context) {
    return SeenTravelerChips(
      padding: EdgeInsets.zero,
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

class _TravelerCard extends StatelessWidget {
  const _TravelerCard({required this.state});

  final ServiceBookingInProgress state;

  /// Figma 09 puts these field pairs side by side (nationality | passport
  /// expiry; birth date | passport issue). A pair is only drawn as a row when
  /// both of its fields exist in the service's form.
  static const _pairs = {
    'nationality': 'passportExpiryDate',
    'birthDate': 'passportIssueDate',
  };

  Widget _field(BuildContext context, DynamicFormField field, TravelerInfo traveler, Map<String, String> errors) =>
      SeenDynamicField(
        key: ValueKey('${traveler.id}-${field.key}'),
        field: field,
        value: traveler.fieldValues[field.key],
        errorText: errors[field.key],
        ltr: _ltrFieldKeys.contains(field.key),
        onChanged: (value) => context.read<ServiceBookingBloc>().add(
              TravelerFieldChanged(
                travelerIndex: state.activeTravelerIndex,
                fieldKey: field.key,
                value: value,
              ),
            ),
      );

  List<Widget> _fieldWidgets(
    BuildContext context,
    ServiceBookingInProgress state,
    TravelerInfo traveler,
    Map<String, String> errors,
    Object? expiry,
  ) {
    final byKey = {for (final f in state.travelerFields) f.key: f};
    final secondOfPair = {
      for (final e in _pairs.entries)
        if (byKey.containsKey(e.key) && byKey.containsKey(e.value)) e.value,
    };
    final out = <Widget>[];
    for (final field in state.travelerFields) {
      if (secondOfPair.contains(field.key)) continue;
      final partner = secondOfPair.contains(_pairs[field.key]) ? byKey[_pairs[field.key]] : null;
      if (partner == null) {
        out.add(_field(context, field, traveler, errors));
      } else {
        out.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _field(context, field, traveler, errors)),
            const SizedBox(width: 8),
            Expanded(child: _field(context, partner, traveler, errors)),
          ],
        ));
      }
      if ((field.key == _passportExpiryFieldKey || partner?.key == _passportExpiryFieldKey) && expiry is DateTime) {
        out.add(SeenValidityHint.fromDates(expiry: expiry, travelDate: DateTime.now()));
      }
      out.add(const SizedBox(height: 14));
    }
    return out;
  }

  /// Every required field has a value (a UX hint; the validator decides).
  bool _isComplete(Map<String, Object?> values) => state.travelerFields.where((f) => f.required).every((f) {
        final v = values[f.key];
        return v != null && !(v is String && v.trim().isEmpty);
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final traveler = state.activeTraveler;
    final errors = state.travelerErrors[traveler.id] ?? const <String, String>{};
    final expiry = traveler.fieldValues[_passportExpiryFieldKey];

    final (chipStatus, chipLabel) = errors.isNotEmpty
        ? (SeenRequestStatus.rejected, l10n.travelerStateIncomplete)
        : _isComplete(traveler.fieldValues)
            ? (SeenRequestStatus.completed, l10n.travelerStateReady)
            : (SeenRequestStatus.newRequest, l10n.travelerStateNew);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.travelerOf(state.activeTravelerIndex + 1, state.travelers.length), style: type.title),
                ),
                SeenStatusChip(status: chipStatus, label: chipLabel),
              ],
            ),
            const SizedBox(height: 14),
            ..._fieldWidgets(context, state, traveler, errors, expiry),
            // No file-picker / upload API yet: the slot is visual only and
            // says so, rather than faking an attachment.
            SeenDropzone(
              title: l10n.travelerAttachmentLabel,
              caption: l10n.attachmentComingSoon,
              onTap: () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l10n.attachmentComingSoon))),
            ),
            if (state.travelers.length > 1) ...[
              const SizedBox(height: 14),
              SeenButton.destructive(
                label: l10n.removeTravelerAction,
                size: SeenButtonSize.small,
                expand: true,
                onPressed: () =>
                    context.read<ServiceBookingBloc>().add(TravelerRemoved(state.activeTravelerIndex)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionsBar extends StatelessWidget {
  const _ActionsBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SeenActionBar(
      actions: [
        SeenButton(
          label: l10n.bookingNextAction,
          expand: true,
          onPressed: () => context.read<ServiceBookingBloc>().add(const TravelerContinuePressed()),
        ),
        SeenButton.secondary(
          label: l10n.bookingBackAction,
          expand: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
