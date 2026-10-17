import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/help_card.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/search_field.dart';
import '../../../../core/presentation/widgets/service_tile.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../dynamic_forms/domain/validators/dynamic_field_validator.dart';
import '../../../dynamic_forms/domain/validators/form_validation_messages.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';
import '../../domain/entities/booking_draft.dart';
import '../../domain/entities/service_definition.dart';
import '../bloc/service_booking_bloc.dart';
import '../bloc/service_booking_event.dart';
import '../bloc/service_booking_state.dart';
import '../widgets/service_card_copy.dart';
import '../widgets/service_traveler_fields.dart';
import 'traveler_entry_screen.dart';

const _gutter = 20.0;

/// Service catalog (Figma 08) and entry point of the booking flow: lists every
/// [ServiceDefinition] the backend returns as Figma service tiles, with a live
/// search, group chips and a support card.
class ServiceSelectionScreen extends StatelessWidget {
  const ServiceSelectionScreen({super.key, this.resumeDraft});

  /// Opens the traveler form straight away with this saved draft (Figma
  /// REQ-01 "Continue"); backing out of it returns to the drafts list.
  final BookingDraft? resumeDraft;

  static DynamicFieldValidator buildValidator(AppLocalizations l10n) =>
      DynamicFieldValidator(
        FormValidationMessages(
          required: l10n.validationRequired,
          invalidEmail: l10n.validationInvalidEmail,
          invalidPhone: l10n.validationInvalidPhone,
          invalidNumber: l10n.validationInvalidNumber,
          invalidDate: l10n.validationInvalidDate,
          invalidSelection: l10n.validationInvalidSelection,
          tooShort: l10n.validationMinLength,
          tooLong: l10n.validationMaxLength,
          numberTooSmall: l10n.validationNumberTooSmall,
          numberTooLarge: l10n.validationNumberTooLarge,
          expiryTooSoon: l10n.validationExpiryTooSoon,
          dateInFuture: l10n.validationDateInFuture,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createServiceBookingBloc(
        validator: buildValidator(l10n),
      )..add(const ServiceCatalogRequested()),
      child: MultiBlocListener(
        listeners: [
          if (resumeDraft != null)
            BlocListener<ServiceBookingBloc, ServiceBookingState>(
              listenWhen: (previous, current) =>
                  previous is! ServiceCatalogLoaded &&
                  current is ServiceCatalogLoaded,
              listener: (context, state) {
                final services = (state as ServiceCatalogLoaded).services;
                final match = services.where(
                    (s) => s.id == resumeDraft!.serviceId && s.isBookable);
                if (match.isEmpty) {
                  // The service was withdrawn since the draft was saved.
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                        SnackBar(content: Text(l10n.draftServiceGone)));
                  Navigator.of(context).pop();
                  return;
                }
                context.read<ServiceBookingBloc>().add(BookingDraftResumed(
                      service: match.first,
                      travelerFields: ServiceTravelerFields.forCategory(
                          match.first.category, l10n),
                      draft: resumeDraft!,
                    ));
              },
            ),
        ],
        child: BlocListener<ServiceBookingBloc, ServiceBookingState>(
          // Only the transition INTO an in-progress booking should push the
          // next screen — this widget stays mounted underneath
          // TravelerEntryScreen, so without the `previous is!` guard every
          // subsequent in-progress emission (each keystroke) would push a
          // duplicate route.
          listenWhen: (previous, current) =>
              previous is! ServiceBookingInProgress &&
              current is ServiceBookingInProgress,
          listener: (context, state) {
            // A route pushed via Navigator is NOT a descendant of this
            // screen's widget tree (it attaches to the Navigator's Overlay),
            // so the BlocProvider above can't be found by `context.read`
            // there without explicitly forwarding the same instance.
            final bloc = context.read<ServiceBookingBloc>();
            Navigator.of(context)
                .push(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: bloc,
                  child: const TravelerEntryScreen(),
                ),
              ),
            )
                .then((_) {
              // Backing out of the booking leaves the bloc in its in-progress
              // state, which would keep this screen on a spinner (and block
              // selecting again): bring the catalog back.
              if (!context.mounted) return;
              // Resumed from the drafts list: go back to it, not to the catalog.
              if (resumeDraft != null) {
                Navigator.of(context).pop();
              } else {
                bloc.add(const ServiceCatalogRequested());
              }
            });
          },
          child: Scaffold(
            backgroundColor: c.card,
            body: SeenScreenBackground(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    SeenScreenHeader(
                        title: l10n.servicesNewTitle,
                        subtitle: l10n.servicesNewSubtitle),
                    Expanded(
                      child:
                          BlocBuilder<ServiceBookingBloc, ServiceBookingState>(
                        builder: (context, state) => switch (state) {
                          ServiceBookingInitial() ||
                          ServiceCatalogLoading() ||
                          ServiceBookingInProgress() =>
                            const Center(child: SeenLoader()),
                          ServiceCatalogFailure(:final message) =>
                            _ErrorView(message: message),
                          ServiceCatalogLoaded(:final services) =>
                            ServiceCatalogView(services: services),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: SeenSpace.s3),
          SeenButton(
            label: l10n.retry,
            onPressed: () => context
                .read<ServiceBookingBloc>()
                .add(const ServiceCatalogRequested()),
          ),
        ],
      ),
    );
  }
}

/// The catalog body (Figma 08): search, one section of service tiles (three
/// per row) and the support card. Needs a [ServiceBookingBloc] above it
/// (tapping a tile selects the service).
class ServiceCatalogView extends StatefulWidget {
  const ServiceCatalogView({super.key, required this.services});

  final List<ServiceDefinition> services;

  @override
  State<ServiceCatalogView> createState() => _ServiceCatalogViewState();
}

class _ServiceCatalogViewState extends State<ServiceCatalogView> {
  // Owned here: created with the view, disposed in dispose().
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    const gap = SizedBox(height: 18);

    final query = _query.trim().toLowerCase();
    final visible = [
      for (final s in widget.services)
        if (query.isEmpty ||
            s.name.toLowerCase().contains(query) ||
            s.description.toLowerCase().contains(query))
          s,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, SeenSpace.s8),
      children: [
        SeenSearchField(
          hint: l10n.servicesSearchHint,
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
        ),
        gap,
        if (widget.services.isEmpty)
          SizedBox(
            height: 320,
            child: SeenEmptyState(
              iconAsset: SeenVectors.iconRequests,
              title: l10n.servicesTitle,
              message: l10n.servicesEmpty,
            ),
          )
        else if (visible.isEmpty)
          SizedBox(
            height: 320,
            child: SeenEmptyState(
              iconAsset: SeenVectors.iconRequests,
              title: l10n.servicesNoResults,
              message: l10n.servicesNoResultsHint,
            ),
          )
        else ...[
          // Figma order: visas first, then approvals and travel. A section with no
          // services is not drawn.
          for (final g in ServiceGroup.values)
            if (visible.any((s) => s.category.group == g)) ...[
              Text(
                g == ServiceGroup.visas
                    ? l10n.servicesSectionVisas
                    : l10n.servicesSectionApprovalsTravel,
                style: type.h2.copyWith(color: c.ink),
              ),
              gap,
              _ServiceGrid(services: [
                for (final s in visible)
                  if (s.category.group == g) s
              ]),
              gap,
            ],
        ],
        SeenHelpCard(
          title: l10n.servicesHelpTitle,
          subtitle: l10n.servicesHelpSubtitle,
          actionLabel: l10n.servicesHelpAction,
          onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SupportTicketsScreen())),
        ),
      ],
    );
  }
}

/// Three tiles per row, 8 px apart; a row is as tall as its tallest tile
/// (104 px minimum) so wrapped names still fit.
class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.services});

  final List<ServiceDefinition> services;

  @override
  Widget build(BuildContext context) {
    const columns = 3;
    final rows = <Widget>[];
    for (var i = 0; i < services.length; i += columns) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = i; j < i + columns; j++) ...[
              if (j > i) const SizedBox(width: 8),
              Expanded(
                child: j < services.length
                    ? _ServiceTile(service: services[j])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ));
      if (i + columns < services.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});

  final ServiceDefinition service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final facts = ServiceCardCopy.forCategory(service.category, l10n);
    return SeenServiceTile(
      label: service.name,
      iconAsset: facts.iconAsset,
      labelLines: 2,
      soon: !service.isBookable,
      soonLabel: service.isBookable ? null : l10n.serviceComingSoonBadge,
      onTap: service.isBookable
          ? () => context.read<ServiceBookingBloc>().add(
                ServiceSelected(
                  service: service,
                  travelerFields:
                      ServiceTravelerFields.forCategory(service.category, l10n),
                ),
              )
          : null,
    );
  }
}
