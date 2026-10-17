import 'package:equatable/equatable.dart';

/// Per-traveler outcome within a request.
///
/// TODO(backend-contract): not part of the confirmed Task 01 enum catalog —
/// a placeholder pending the real Seen Booking schema.
enum TravelerApprovalStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  unknown('');

  const TravelerApprovalStatus(this.value);
  final String value;

  static TravelerApprovalStatus fromValue(String? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return TravelerApprovalStatus.unknown;
  }
}

/// Where a traveler's document stands (Figma REQ-12).
///
/// TODO(backend-contract): placeholder wire values (docs/BACKEND_MIGRATION_GAPS.md, section 22).
enum TravelerDocumentStatus {
  issued('ISSUED'),
  approved('APPROVED'),
  inReview('IN_REVIEW'),
  unknown('');

  const TravelerDocumentStatus(this.value);
  final String value;

  static TravelerDocumentStatus fromValue(String? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return TravelerDocumentStatus.unknown;
  }
}

/// One document of one traveler: an issued approval, a passport scan under
/// review, ... [url] is where the viewer fetches it.
class TravelerDocument extends Equatable {
  const TravelerDocument({required this.name, required this.status, this.url});

  final String name;
  final String? url;
  final TravelerDocumentStatus status;

  @override
  List<Object?> get props => [name, url, status];
}

class RequestTravelerStatus extends Equatable {
  const RequestTravelerStatus({
    required this.name,
    required this.status,
    this.passportNumber,
    this.documents = const [],
  });

  final String name;
  final String? passportNumber;
  final TravelerApprovalStatus status;
  final List<TravelerDocument> documents;

  @override
  List<Object?> get props => [name, passportNumber, status, documents];
}
