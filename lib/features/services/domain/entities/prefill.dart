import 'package:equatable/equatable.dart';

/// An earlier request the agency may copy details from when filing a service (an
/// admin-set rule per service, e.g. the airline circular from its security
/// approval). The server lists them without personal data. Pure Dart.
class PrefillCandidate extends Equatable {
  const PrefillCandidate({
    required this.requestId,
    required this.referenceCode,
    required this.serviceName,
    required this.travelerCount,
    this.createdAt,
  });

  final String requestId;
  final String referenceCode;

  /// In the language the app shows.
  final String serviceName;
  final int travelerCount;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [requestId, referenceCode, serviceName, travelerCount, createdAt];
}

/// The values of an earlier request, per traveler and keyed by the field key of the
/// service being filed. They are suggestions: nothing is saved or sent until the
/// person has seen them in the form and continued.
class PrefillValues extends Equatable {
  const PrefillValues(this.travelers);

  final List<Map<String, String>> travelers;

  bool get isEmpty => travelers.every((t) => t.isEmpty);

  @override
  List<Object?> get props => [travelers];
}
