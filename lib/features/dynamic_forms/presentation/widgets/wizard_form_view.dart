import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../bloc/wizard_form_cubit.dart';
import '../bloc/wizard_form_state.dart';
import 'dynamic_field_widget.dart';

/// Renders the current step of a [WizardFormCubit] with Back/Next
/// navigation. Reusable across any set of wizard steps — nothing here is
/// specific to a particular form.
class WizardFormView extends StatelessWidget {
  const WizardFormView({super.key, required this.onCompleted});

  /// Called once, when `nextStep()` succeeds from the last step.
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<WizardFormCubit, WizardFormState>(
      builder: (context, state) {
        final cubit = context.read<WizardFormCubit>();
        final step = state.currentStep;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.wizardStepIndicator(state.stepIndex + 1, state.steps.length),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(step.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final field in step.fields)
              DynamicFieldWidget(
                key: ValueKey(field.key),
                field: field,
                value: state.values[field.key],
                errorText: state.errors[field.key],
                onChanged: (value) => cubit.updateField(field.key, value),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (!state.isFirstStep)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: cubit.previousStep,
                      child: Text(l10n.wizardBack),
                    ),
                  ),
                if (!state.isFirstStep) const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final wasLastStep = state.isLastStep;
                      if (cubit.nextStep() && wasLastStep) onCompleted();
                    },
                    child: Text(state.isLastStep ? l10n.wizardFinish : l10n.wizardNext),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
