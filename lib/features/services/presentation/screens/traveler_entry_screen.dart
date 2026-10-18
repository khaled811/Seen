import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/form_stepper.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
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
import '../bloc/traveler_attachment_cubit.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/booking_draft.dart';
import '../utils/draft_summary.dart';
import '../widgets/save_draft_sheet.dart';
import '../../../dynamic_forms/domain/validators/passport_validators.dart';
import '../widgets/seen_attachment_slot.dart';
import '../widgets/seen_dynamic_field.dart';
import '../widgets/seen_traveler_chips.dart' show SeenTravelerState;
import '../widgets/seen_traveler_switcher.dart';
import '../widgets/seen_validity_hint.dart';
import 'booking_review_screen.dart';

const _passportExpiryFieldKey = 'passportExpiryDate';
const _passportIssueFieldKey = 'passportIssueDate';
const _gutter = 20.0;

/// The traveler's passport fails the 6-month rule against today (the travel date the app uses).
bool _passportBlocked(TravelerInfo t, DateTime now) {
  final expiry = t.fieldValues[_passportExpiryFieldKey];
  return expiry is DateTime && !PassportValidators.isValidExpiryDate(expiry, now: now);
}

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
    return BlocProvider(
      // The picker is resolved on first use, so tests never touch the plugins.
      create: (_) => TravelerAttachmentCubit(
          () => InjectionContainer.instance.documentPicker),
      child: BlocListener<ServiceBookingBloc, ServiceBookingState>(
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
                  value: bloc, child: const BookingReviewScreen()),
            ),
          );
        },
        child: BlocBuilder<ServiceBookingBloc, ServiceBookingState>(
          buildWhen: (previous, current) =>
              _isDirty(previous) != _isDirty(current),
          // Leaving with data entered asks whether to keep it as a draft (REQ-04).
          builder: (context, state) => PopScope(
            canPop: !_isDirty(state),
            onPopInvoked: (didPop) {
              if (!didPop) _askToSaveDraft(context);
            },
            child: _scaffold(context, c),
          ),
        ),
      ),
    );
  }

  static bool _isDirty(ServiceBookingState state) =>
      state is ServiceBookingInProgress && hasAnyTravelerData(state.travelers);

  Future<void> _askToSaveDraft(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<ServiceBookingBloc>();
    final state = bloc.state;
    if (state is! ServiceBookingInProgress) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = InjectionContainer.instance;
    final existing =
        (await container.getBookingDraftsUseCase()).getOrElse((_) => const []);
    if (!context.mounted) return;
    final choice = await showSaveDraftSheet(
      context,
      travelers: travelerCompleteness(state.travelers, state.travelerFields),
      existingDrafts: existing.length,
      isUpdate:
          state.draftId != null && existing.any((d) => d.id == state.draftId),
    );
    switch (choice) {
      case null:
        return; // dismissed: stay on the form
      case LeaveFormChoice.discard:
        navigator.pop();
      case LeaveFormChoice.save:
        final id =
            state.draftId ?? 'draft-${DateTime.now().microsecondsSinceEpoch}';
        final saved = await container.saveBookingDraftUseCase(BookingDraft(
          id: id,
          serviceId: state.service.id,
          serviceName: state.service.name,
          category: state.service.category,
          travelers: state.travelers,
          updatedAt: DateTime.now(),
        ));
        final ok = saved.fold((_) => false, (r) => r == SaveDraftResult.saved);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(ok ? l10n.draftSaved : l10n.recoveryServerError)));
        if (ok) {
          bloc.add(BookingDraftSaved(id));
          navigator.pop();
        }
    }
  }

  Widget _scaffold(BuildContext context, SeenColors c) {
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: BlocBuilder<ServiceBookingBloc, ServiceBookingState>(
            builder: (context, state) {
              if (state is! ServiceBookingInProgress) {
                return const Center(child: SeenLoader());
              }
              final s = SeenStrings.of(context);
              return Column(
                children: [
                  SeenScreenHeader(
                      title: state.service.name, subtitle: s.bookingStep(2, 3)),
                  Expanded(child: _Body(state: state)),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: BlocBuilder<ServiceBookingBloc, ServiceBookingState>(
        buildWhen: (previous, current) =>
            (previous is ServiceBookingInProgress) !=
            (current is ServiceBookingInProgress),
        builder: (context, state) {
          if (state is! ServiceBookingInProgress) {
            return const SizedBox.shrink();
          }
          return const _ActionsBar();
        },
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
      padding: const EdgeInsets.fromLTRB(
          _gutter, SeenSpace.s1, _gutter, SeenSpace.s6),
      children: [
        SeenFormStepper(
          labels: [
            l10n.bookingStepService,
            l10n.bookingStepTravelers,
            l10n.bookingStepReview
          ],
          current: 1,
        ),
        const SizedBox(height: SeenSpace.s4),
        _TravelerTabs(state: state),
        const SizedBox(height: 8),
        Text(l10n.bookingTravelerLimit,
            style: SeenType.of(context)
                .caption
                .copyWith(color: SeenColors.of(context).inkMuted)),
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
        _IssueBanner(state: state),
      ],
    );
  }
}

class _TravelerTabs extends StatelessWidget {
  const _TravelerTabs({required this.state});

  final ServiceBookingInProgress state;

  @override
  Widget build(BuildContext context) {
    return SeenTravelerSwitcher(
      states: [
        for (final traveler in state.travelers)
          (state.travelerErrors[traveler.id]?.isNotEmpty ?? false)
              ? SeenTravelerState.error
              : (traveler.fieldValues.isNotEmpty
                  ? SeenTravelerState.done
                  : SeenTravelerState.empty),
      ],
      activeIndex: state.activeTravelerIndex,
      onSelected: (i) =>
          context.read<ServiceBookingBloc>().add(ActiveTravelerChanged(i)),
      // At the limit the "+" is shown disabled (the note below says why).
      onAdd: state.travelers.length >= maxTravelersPerRequest
          ? null
          : () => context.read<ServiceBookingBloc>().add(const TravelerAdded()),
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

  Widget _field(BuildContext context, DynamicFormField field,
          TravelerInfo traveler, Map<String, String> errors) =>
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
      final partner = secondOfPair.contains(_pairs[field.key])
          ? byKey[_pairs[field.key]]
          : null;
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
      if ((field.key == _passportExpiryFieldKey ||
              partner?.key == _passportExpiryFieldKey) &&
          expiry is DateTime) {
        out.add(SeenValidityHint.fromDates(
            expiry: expiry, travelDate: DateTime.now()));
      }
      out.add(const SizedBox(height: 14));
    }
    return out;
  }

  /// Every required field has a value (a UX hint; the validator decides).
  bool _isComplete(Map<String, Object?> values) =>
      state.travelerFields.where((f) => f.required).every((f) {
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
    final now = DateTime.now();
    final expiry = traveler.fieldValues[_passportExpiryFieldKey];
    final issue = traveler.fieldValues[_passportIssueFieldKey];
    final blocked = _passportBlocked(traveler, now);
    // Shown as the user types (Figma SYS-09), on top of what "Next" reported.
    final errors = {
      ...(state.travelerErrors[traveler.id] ?? const <String, String>{}),
      if (issue is DateTime && issue.isAfter(now)) _passportIssueFieldKey: s.issueDateInFuture,
      if (blocked) _passportExpiryFieldKey: s.expiryRuleError(now),
    };

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
        padding:
            const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      s.travelerOf(state.activeTravelerIndex + 1,
                          state.travelers.length),
                      style: type.title),
                ),
                SeenStatusChip(status: chipStatus, label: chipLabel),
              ],
            ),
            const SizedBox(height: 14),
            ..._fieldWidgets(context, state, traveler, errors, expiry),
            if (blocked) ...[const _SixMonthRule(), const SizedBox(height: 14)],
            // No booking-attachment upload API yet: the file stays on the device
            // and the slot says so (see TravelerAttachmentCubit).
            SeenAttachmentSlot(
              travelerId: traveler.id,
              title: l10n.travelerAttachmentLabel,
              caption: s.attachTypes,
            ),
            if (state.travelers.length > 1) ...[
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SeenTextLink(
                  label: l10n.removeThisTravelerAction,
                  onTap: () => context
                      .read<ServiceBookingBloc>()
                      .add(TravelerRemoved(state.activeTravelerIndex)),
                ),
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
    final s = SeenStrings.of(context);
    return BlocBuilder<ServiceBookingBloc, ServiceBookingState>(
      builder: (context, state) {
        final progress = state is ServiceBookingInProgress ? state : null;
        final now = DateTime.now();
        // A passport under the 6-month rule blocks "Next" for the whole request (Figma SYS-09).
        final blocked = progress != null && progress.travelers.any((t) => _passportBlocked(t, now));
        final activeBlocked = progress != null && _passportBlocked(progress.activeTraveler, now);
        final canRemove = progress != null && activeBlocked && progress.travelers.length > 1;
        final next = SeenButton(
          label: l10n.bookingNextAction,
          expand: true,
          onPressed: blocked
              ? null
              : () => context.read<ServiceBookingBloc>().add(const TravelerContinuePressed()),
        );
        if (blocked) {
          return SeenActionBar(
            actions: [
              canRemove
                  ? SeenButton.outline(
                      label: s.removeTravelerButton,
                      expand: true,
                      onPressed: () => context
                          .read<ServiceBookingBloc>()
                          .add(TravelerRemoved(progress.activeTravelerIndex)),
                    )
                  : SeenButton.outline(
                      label: l10n.bookingBackAction,
                      expand: true,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
              next,
            ],
          );
        }
        return SeenActionBar(
          actions: [
            next,
            SeenButton.secondary(
              label: l10n.bookingBackAction,
              expand: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        );
      },
    );
  }
}

/// Why the request cannot go on, and what is accepted (Figma SYS-09).
class _SixMonthRule extends StatelessWidget {
  const _SixMonthRule();

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    final bad = SeenRequestStatus.rejected.colors;
    final ok = SeenRequestStatus.completed.colors;
    Widget chip(String label, SeenStatusColors colors) => Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(color: colors.bg, borderRadius: const BorderRadius.all(SeenRadius.full)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  Flexible(child: Text(label, style: t.caption.copyWith(color: colors.fg, fontWeight: FontWeight.w500))),
                  const SizedBox(width: 6),
                  DecoratedBox(
                    decoration: BoxDecoration(color: colors.fg, shape: BoxShape.circle),
                    child: const SizedBox(width: 6, height: 6),
                  ),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: bad.bg, borderRadius: const BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(SeenIcons.alert, size: 18, color: bad.fg),
                      const SizedBox(width: 8),
                      Text(s.sixMonthRuleTitle, style: t.label.copyWith(color: bad.fg)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(s.sixMonthRuleBody, style: t.caption.copyWith(color: bad.fg)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [chip(s.sixMonthLegendOk, ok), const SizedBox(width: 8), chip(s.sixMonthLegendBad, bad)]),
        ],
      ),
    );
  }
}

/// Figma BOOK-02: after "Next" with a problem, say which traveler and what, with a
/// shortcut to that traveler.
class _IssueBanner extends StatelessWidget {
  const _IssueBanner({required this.state});

  final ServiceBookingInProgress state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final index = state.travelers
        .indexWhere((t) => state.travelerErrors[t.id]?.isNotEmpty ?? false);
    if (index < 0) return const SizedBox.shrink();
    final errors = state.travelerErrors[state.travelers[index].id]!;
    final fieldKey = errors.keys.first;
    final label = state.travelerFields
        .where((f) => f.key == fieldKey)
        .map((f) => f.label)
        .firstOrNull;
    final who = s.numeral(index + 1);
    // "Missing X" only when the problem really is a missing value.
    final message = label != null && errors[fieldKey] == l10n.validationRequired
        ? l10n.bookingTravelerMissing(who, label)
        : l10n.bookingTravelerInvalid(who);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SeenInlineBanner(
        tone: SeenBannerTone.error,
        message: message,
        actionLabel: index == state.activeTravelerIndex
            ? null
            : l10n.bookingTravelerShow,
        onAction: () => context
            .read<ServiceBookingBloc>()
            .add(ActiveTravelerChanged(index)),
      ),
    );
  }
}
