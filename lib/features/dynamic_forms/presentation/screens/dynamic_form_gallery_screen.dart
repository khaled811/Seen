import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../domain/entities/dynamic_form_field.dart';
import '../../domain/entities/form_step_definition.dart';
import '../../domain/validators/dynamic_field_validator.dart';
import '../../domain/validators/form_validation_messages.dart';
import '../bloc/wizard_form_cubit.dart';
import '../widgets/wizard_form_view.dart';

/// Temporary functional test harness for the dynamic form engine — exercises
/// every [FieldType], both passport date constraints, and multi-step
/// navigation. Replace with real feature forms once they're specified.
class DynamicFormGalleryScreen extends StatelessWidget {
  const DynamicFormGalleryScreen({super.key});

  List<FormStepDefinition> _buildSteps(AppLocalizations l10n) => [
        FormStepDefinition(
          id: 'personal_info',
          title: l10n.stepPersonalInfoTitle,
          fields: [
            DynamicFormField(
              key: 'fullName',
              type: FieldType.text,
              label: l10n.fieldFullNameLabel,
              required: true,
              minLength: 2,
              maxLength: 100,
            ),
            DynamicFormField(
              key: 'email',
              type: FieldType.email,
              label: l10n.fieldEmailLabel,
              required: true,
            ),
            DynamicFormField(
              key: 'phone',
              type: FieldType.phone,
              label: l10n.fieldPhoneLabel,
              required: true,
            ),
          ],
        ),
        FormStepDefinition(
          id: 'passport_info',
          title: l10n.stepPassportInfoTitle,
          fields: [
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
          ],
        ),
        FormStepDefinition(
          id: 'preferences',
          title: l10n.stepPreferencesTitle,
          fields: [
            DynamicFormField(
              key: 'travelClass',
              type: FieldType.select,
              label: l10n.fieldTravelClassLabel,
              required: true,
              options: [
                FieldOption(value: 'economy', label: l10n.optionEconomy),
                FieldOption(value: 'business', label: l10n.optionBusiness),
              ],
            ),
            DynamicFormField(
              key: 'notes',
              type: FieldType.textarea,
              label: l10n.fieldNotesLabel,
              maxLength: 500,
            ),
          ],
        ),
      ];

  FormValidationMessages _buildMessages(AppLocalizations l10n) =>
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
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.formsGalleryTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: BlocProvider(
            create: (_) => WizardFormCubit(
              steps: _buildSteps(l10n),
              validator: DynamicFieldValidator(_buildMessages(l10n)),
            ),
            child: WizardFormView(
              onCompleted: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l10n.wizardCompleted)));
              },
            ),
          ),
        ),
      ),
    );
  }
}
