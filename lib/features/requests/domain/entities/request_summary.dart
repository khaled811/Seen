import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// One row on the Requests Dashboard.
class RequestSummary extends Equatable {
  const RequestSummary({
    required this.id,
    required this.referenceId,
    required this.serviceName,
    required this.travelerCount,
    required this.totalPriceCents,
    required this.status,
    required this.submittedAt,
    this.slaDeadline,
    this.rejectionNote,
    this.travelerNames = const [],
  });

  final String id;
  final String referenceId;
  final String serviceName;
  final int travelerCount;
  final int totalPriceCents;
  final RequestStatus status;
  final DateTime submittedAt;

  /// Only meaningful (and only ever set) while [status] is
  /// [RequestStatus.infoRequired] — the 72-hour SLA deadline.
  final DateTime? slaDeadline;

  /// Direct rejection/action summary text when status == infoRequired.
  final String? rejectionNote;

  /// Names of the request's travelers, for the reference / traveler search.
  final List<String> travelerNames;

  @override
  List<Object?> get props => [
        id,
        referenceId,
        serviceName,
        travelerCount,
        totalPriceCents,
        status,
        submittedAt,
        slaDeadline,
        rejectionNote,
        travelerNames,
      ];
}
