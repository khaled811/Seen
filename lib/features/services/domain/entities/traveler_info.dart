import 'package:equatable/equatable.dart';

/// One traveler's captured data for a booking.
///
/// [fieldValues] is keyed by the originating `DynamicFormField.key` (see
/// `features/dynamic_forms`) — a `String` for text-like fields, `DateTime`
/// for date fields, matching that engine's value convention exactly.
class TravelerInfo extends Equatable {
  const TravelerInfo({required this.id, required this.fieldValues});

  /// Local, session-only identifier for list management (add/remove/track
  /// errors) — never sent to or received from the backend.
  final String id;

  final Map<String, Object?> fieldValues;

  TravelerInfo copyWith({Map<String, Object?>? fieldValues}) =>
      TravelerInfo(id: id, fieldValues: fieldValues ?? this.fieldValues);

  @override
  List<Object?> get props => [id, fieldValues];
}
