import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';
import '../../domain/entities/service_definition.dart';
import 'nationality_options.dart';

/// Resolves which per-traveler fields a service needs, with localized
/// labels. Lives in presentation (not the domain `ServiceDefinition`
/// entity) because building labels needs `AppLocalizations` — mirrors how
/// `WalletLabels` maps enums to display text.
abstract final class ServiceTravelerFields {
  static List<DynamicFormField> forCategory(
    ServiceCategory category,
    AppLocalizations l10n,
  ) =>
      switch (category) {
        ServiceCategory.egyptNationalSecurity ||
        ServiceCategory.egyptMilitaryIntelligence ||
        ServiceCategory.medicalJordan =>
          _egyptApprovalFields(l10n),
        ServiceCategory.egyptAirlineCircular ||
        ServiceCategory.jordanApprovals ||
        ServiceCategory.unknown =>
          const [],
      };

  static List<DynamicFormField> _egyptApprovalFields(AppLocalizations l10n) => [
        DynamicFormField(
          key: 'fullName',
          type: FieldType.text,
          label: l10n.fieldFullNameLabel,
          required: true,
          minLength: 2,
          maxLength: 100,
        ),
        DynamicFormField(
          key: 'passportNumber',
          type: FieldType.text,
          label: l10n.travelerPassportNumberLabel,
          required: true,
          minLength: 6,
          maxLength: 20,
        ),
        DynamicFormField(
          key: 'nationality',
          type: FieldType.select,
          label: l10n.travelerNationalityLabel,
          required: true,
          options: nationalityOptions(arabic: l10n.localeName == 'ar'),
        ),
        DynamicFormField(
          key: 'birthDate',
          type: FieldType.date,
          label: l10n.fieldBirthDateLabel,
          required: true,
          dateConstraint: DateFieldConstraint.notInFuture,
        ),
        DynamicFormField(
          key: 'passportIssueDate',
          type: FieldType.date,
          label: l10n.fieldPassportIssueDateLabel,
          required: true,
          dateConstraint: DateFieldConstraint.notInFuture,
        ),
        DynamicFormField(
          key: 'passportExpiryDate',
          type: FieldType.date,
          label: l10n.fieldPassportExpiryDateLabel,
          required: true,
          dateConstraint: DateFieldConstraint.minMonthsInFuture,
          minMonthsInFuture: 6,
        ),
      ];
}
