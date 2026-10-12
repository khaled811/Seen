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

class RequestTravelerStatus extends Equatable {
  const RequestTravelerStatus({
    required this.name,
    required this.status,
    this.passportNumber,
  });

  final String name;
  final String? passportNumber;
  final TravelerApprovalStatus status;

  @override
  List<Object?> get props => [name, passportNumber, status];
}
