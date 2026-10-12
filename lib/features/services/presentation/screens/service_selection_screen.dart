import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/tag.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../dynamic_forms/domain/validators/dynamic_field_validator.dart';
import '../../../dynamic_forms/domain/validators/form_validation_messages.dart';
import '../../domain/entities/service_definition.dart';
import '../bloc/service_booking_bloc.dart';
import '../bloc/service_booking_event.dart';
import '../bloc/service_booking_state.dart';
import '../widgets/service_card_copy.dart';
import '../widgets/service_traveler_fields.dart';
import '../widgets/seen_service_card.dart';
import 'traveler_entry_screen.dart';

/// Entry point for the Egypt Approvals booking flow: lists every
/// [ServiceDefinition] the backend returns, skinned with [SeenServiceCard].
class ServiceSelectionScreen extends StatelessWidget {
  const ServiceSelectionScreen({super.key});

  static DynamicFieldValidator buildValidator(AppLocalizations l10n) => DynamicFieldValidator(
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
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createServiceBookingBloc(
        validator: buildValidator(l10n),
      )..add(const ServiceCatalogRequested()),
      child: BlocListener<ServiceBookingBloc, ServiceBookingState>(
        // Only the transition INTO an in-progress booking should push the
        // next screen — this widget stays mounted underneath
        // TravelerEntryScreen, so without the `previous is!` guard every
        // subsequent in-progress emission (each keystroke) would push a
        // duplicate route.
        listenWhen: (previous, current) =>
            previous is! ServiceBookingInProgress && current is ServiceBookingInProgress,
        listener: (context, state) {
          // A route pushed via Navigator is NOT a descendant of this
          // screen's widget tree (it attaches to the Navigator's Overlay),
          // so the BlocProvider above can't be found by `context.read`
          // there without explicitly forwarding the same instance.
          final bloc = context.read<ServiceBookingBloc>();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: const TravelerEntryScreen(),
              ),
            ),
          );
        },
        child: Scaffold(
          appBar: SeenTopBar.inner(title: l10n.servicesTitle),
          body: BlocBuilder<ServiceBookingBloc, ServiceBookingState>(
            builder: (context, state) {
              return switch (state) {
                ServiceBookingInitial() ||
                ServiceCatalogLoading() ||
                ServiceBookingInProgress() =>
                  const Center(child: SeenLoader()),
                ServiceCatalogFailure(:final message) => _ErrorView(message: message),
                ServiceCatalogLoaded(:final services) => _CatalogView(services: services),
              };
            },
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
            onPressed: () => context.read<ServiceBookingBloc>().add(const ServiceCatalogRequested()),
          ),
        ],
      ),
    );
  }
}

class _CatalogView extends StatelessWidget {
  const _CatalogView({required this.services});

  final List<ServiceDefinition> services;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(SeenSpace.s4),
      itemCount: services.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: SeenSpace.s3),
        child: _ServiceCard(service: services[index]),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final ServiceDefinition service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final facts = ServiceCardCopy.forCategory(service.category, l10n);
    final card = SeenServiceCard(
      icon: facts.icon,
      title: service.name,
      subtitle: service.description,
      pricePerTraveler: service.perPersonPriceCents / 100,
      processing: facts.processing,
      documents: facts.documents,
      onTap: service.isBookable
          ? () => context.read<ServiceBookingBloc>().add(
                ServiceSelected(
                  service: service,
                  travelerFields: ServiceTravelerFields.forCategory(service.category, l10n),
                ),
              )
          : null,
    );
    if (service.isBookable) return card;
    return Stack(
      children: [
        Opacity(opacity: .55, child: IgnorePointer(child: card)),
        PositionedDirectional(top: SeenSpace.s3, end: SeenSpace.s3, child: SeenTag(l10n.serviceComingSoonBadge)),
      ],
    );
  }
}
