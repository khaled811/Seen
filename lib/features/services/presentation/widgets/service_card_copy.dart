// Presentation-only per-category facts for SeenServiceCard (icon, processing
// time, required documents). `ServiceDefinition` deliberately doesn't carry
// these — see its doc comment — so, like `ServiceTravelerFields.forCategory`,
// this is a static resolver keyed by category rather than a domain field.
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../domain/entities/service_definition.dart';

class ServiceCardFacts {
  const ServiceCardFacts({
    required this.icon,
    required this.iconAsset,
    required this.processing,
    required this.documents,
  });

  final IconData icon;

  /// Figma SVG icon for catalog tiles and review.
  final String iconAsset;
  final String processing;
  final String documents;
}

abstract final class ServiceCardCopy {
  static ServiceCardFacts forCategory(ServiceCategory category, AppLocalizations l10n) => switch (category) {
        ServiceCategory.egyptNationalSecurity => ServiceCardFacts(
            icon: SeenIcons.shield,
            iconAsset: SeenVectors.iconJordanSecurity,
            processing: l10n.serviceProcessingEgyptNationalSecurity,
            documents: l10n.serviceDocumentsEgyptNationalSecurity,
          ),
        ServiceCategory.egyptMilitaryIntelligence => ServiceCardFacts(
            icon: SeenIcons.radar,
            iconAsset: SeenVectors.iconJordanSecurity,
            processing: l10n.serviceProcessingEgyptMilitaryIntelligence,
            documents: l10n.serviceDocumentsEgyptMilitaryIntelligence,
          ),
        ServiceCategory.egyptAirlineCircular ||
        ServiceCategory.jordanApprovals ||
        ServiceCategory.unknown =>
          ServiceCardFacts(
            icon: SeenIcons.file,
            iconAsset: category == ServiceCategory.egyptAirlineCircular
                ? SeenVectors.iconFlight
                : category == ServiceCategory.jordanApprovals
                    ? SeenVectors.iconJordanSecurity
                    : SeenVectors.iconRequests,
            processing: l10n.serviceFactUnavailable,
            documents: l10n.serviceFactUnavailable,
          ),
      };
}

/// Catalog grouping (presentation only). The backend taxonomy is still a
/// placeholder (see [ServiceCategory]), so groups are derived from it and only
/// the ones that actually contain services are shown.
enum ServiceGroup { approvals, travel, other }

extension ServiceCategoryGroup on ServiceCategory {
  ServiceGroup get group => switch (this) {
        ServiceCategory.egyptNationalSecurity ||
        ServiceCategory.egyptMilitaryIntelligence ||
        ServiceCategory.jordanApprovals =>
          ServiceGroup.approvals,
        ServiceCategory.egyptAirlineCircular => ServiceGroup.travel,
        ServiceCategory.unknown => ServiceGroup.other,
      };
}
