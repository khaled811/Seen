import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/form_step_definition.dart';
import '../../domain/validators/dynamic_field_validator.dart';
import 'wizard_form_state.dart';

/// Reusable multi-step wizard controller: tracks the current step, holds
/// every step's field values (so going back and forth doesn't lose earlier
/// input), and validates a step's fields before advancing past it.
class WizardFormCubit extends Cubit<WizardFormState> {
  WizardFormCubit({
    required List<FormStepDefinition> steps,
    required DynamicFieldValidator validator,
  })  : assert(steps.isNotEmpty, 'A wizard needs at least one step.'),
        _validator = validator,
        super(WizardFormState.initial(steps));

  final DynamicFieldValidator _validator;

  void updateField(String key, Object? value) {
    final values = Map<String, Object?>.from(state.values)..[key] = value;
    // Clear this field's error as soon as it's edited; it's re-validated the
    // next time the user tries to advance.
    final errors = Map<String, String>.from(state.errors)..remove(key);
    emit(state.copyWith(values: values, errors: errors));
  }

  /// Validates every field on the current step and updates [WizardFormState.errors].
  /// Returns whether the step is valid.
  bool validateCurrentStep() {
    final errors = <String, String>{};
    for (final field in state.currentStep.fields) {
      final error = _validator.validate(field, state.values[field.key]);
      if (error != null) errors[field.key] = error;
    }
    emit(state.copyWith(errors: errors));
    return errors.isEmpty;
  }

  /// Validates the current step and, if valid, advances to the next one.
  /// Returns whether it advanced (or was already valid on the last step).
  bool nextStep() {
    if (!validateCurrentStep()) return false;
    if (!state.isLastStep) {
      emit(state.copyWith(stepIndex: state.stepIndex + 1, errors: const {}));
    }
    return true;
  }

  /// Goes back a step without validating (revisiting a step to fix earlier
  /// input shouldn't be blocked by the step being left).
  void previousStep() {
    if (state.isFirstStep) return;
    emit(state.copyWith(stepIndex: state.stepIndex - 1, errors: const {}));
  }

  void reset() => emit(WizardFormState.initial(state.steps));
}
