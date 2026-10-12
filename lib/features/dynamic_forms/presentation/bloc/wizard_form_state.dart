import 'package:equatable/equatable.dart';

import '../../domain/entities/form_step_definition.dart';

class WizardFormState extends Equatable {
  const WizardFormState({
    required this.steps,
    required this.stepIndex,
    required this.values,
    required this.errors,
  });

  factory WizardFormState.initial(List<FormStepDefinition> steps) =>
      WizardFormState(
        steps: steps,
        stepIndex: 0,
        values: const {},
        errors: const {},
      );

  final List<FormStepDefinition> steps;
  final int stepIndex;

  /// Field key -> current value (`String` for text-like fields, `DateTime`
  /// for date fields, `String` matching a [FieldOption.value] for select).
  final Map<String, Object?> values;

  /// Field key -> current validation error for fields on the current step.
  final Map<String, String> errors;

  FormStepDefinition get currentStep => steps[stepIndex];
  bool get isFirstStep => stepIndex == 0;
  bool get isLastStep => stepIndex == steps.length - 1;

  WizardFormState copyWith({
    int? stepIndex,
    Map<String, Object?>? values,
    Map<String, String>? errors,
  }) =>
      WizardFormState(
        steps: steps,
        stepIndex: stepIndex ?? this.stepIndex,
        values: values ?? this.values,
        errors: errors ?? this.errors,
      );

  @override
  List<Object?> get props => [steps, stepIndex, values, errors];
}
