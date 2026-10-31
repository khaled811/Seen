import 'package:equatable/equatable.dart';

/// One value sent to `addTraveler` / `batchAddTravelers` (`FieldValueInput`):
/// the server's field definition id and the value as text (dates `YYYY-MM-DD`).
class FieldValueInput extends Equatable {
  const FieldValueInput({required this.fieldDefinitionId, required this.value});

  final String fieldDefinitionId;
  final String value;

  @override
  List<Object?> get props => [fieldDefinitionId, value];
}
