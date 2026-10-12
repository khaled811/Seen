import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import 'request_timeline_entry.dart';
import 'request_traveler_status.dart';

/// Statuses a request can still be cancelled from. Once it reaches one of
/// the terminal states below, cancellation is no longer offered.
const _cancellableStatuses = {
  RequestStatus.draft,
  RequestStatus.submitted,
  RequestStatus.pendingAgentApproval,
  RequestStatus.pendingManagementApproval,
  RequestStatus.underReview,
  RequestStatus.infoRequired,
  RequestStatus.processing,
};

class RequestDetail extends Equatable {
  const RequestDetail({
    required this.id,
    required this.referenceId,
    required this.serviceName,
    required this.status,
    required this.totalPriceCents,
    required this.submittedAt,
    required this.travelers,
    required this.timeline,
    this.slaDeadline,
    this.outputDocumentUrl,
  });

  final String id;
  final String referenceId;
  final String serviceName;
  final RequestStatus status;
  final int totalPriceCents;
  final DateTime submittedAt;
  final List<RequestTravelerStatus> travelers;
  final List<RequestTimelineEntry> timeline;

  /// Only meaningful while [status] is [RequestStatus.infoRequired].
  final DateTime? slaDeadline;

  /// Present only once the request reaches [RequestStatus.completed] — the
  /// output/approval document. Delivery is mocked (per Task 08) until the
  /// backend's document storage is active; see `RequestOutputSection`.
  final String? outputDocumentUrl;

  bool get isCancellable => _cancellableStatuses.contains(status);

  bool get hasOutput => status == RequestStatus.completed;

  @override
  List<Object?> get props => [
        id,
        referenceId,
        serviceName,
        status,
        totalPriceCents,
        submittedAt,
        travelers,
        timeline,
        slaDeadline,
        outputDocumentUrl,
      ];
}
