import 'package:equatable/equatable.dart';

/// One sensitive value of a traveler (passport number, national ID, e-mail, phone) as it may
/// be shown: always the HIDDEN form. The clear text is never part of this entity; it is fetched
/// on demand with the value's [id] and lives only in the reveal controller for 30 seconds.
class SensitiveValue extends Equatable {
  const SensitiveValue({required this.id, required this.label, required this.masked});

  /// The server's `FieldValue.id`, used to reveal it.
  final String id;

  /// The field's name in the app language.
  final String label;

  /// What is shown while hidden (`••••••4821`).
  final String masked;

  @override
  List<Object?> get props => [id, label, masked];
}

/// The sensitive values of one traveler of a request.
class TravelerSensitive extends Equatable {
  const TravelerSensitive({required this.travelerId, required this.values});

  final String travelerId;
  final List<SensitiveValue> values;

  @override
  List<Object?> get props => [travelerId, values];
}
