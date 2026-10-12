import 'package:equatable/equatable.dart';

import 'dynamic_form_field.dart';

/// One page of a multi-step wizard.
class FormStepDefinition extends Equatable {
  const FormStepDefinition({
    required this.id,
    required this.title,
    required this.fields,
  });

  final String id;
  final String title;
  final List<DynamicFormField> fields;

  @override
  List<Object?> get props => [id, title, fields];
}
