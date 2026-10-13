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

/// Catalog sections of Figma 08 (presentation only). The backend has no
/// section field and no visa categories yet, so every category it knows lands
/// in [approvalsTravel]; [visas] stays empty (and hidden) until a visa
/// category exists. See docs/BACKEND_MIGRATION_GAPS.md.
enum ServiceGroup { visas, approvalsTravel }

extension ServiceCategoryGroup on ServiceCategory {
  ServiceGroup get group => ServiceGroup.approvalsTravel;
}
