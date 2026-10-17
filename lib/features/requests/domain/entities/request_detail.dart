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

/// Who has to approve a request that is waiting on an approval step
/// (Figma REQ-06 / 07).
enum ApproverKind { masterAgent, management }

class RequestApprovalInfo extends Equatable {
  const RequestApprovalInfo({required this.kind, this.approverName, this.typicalWaitMinutes, this.thresholdCents});

  final ApproverKind kind;
  final String? approverName;

  /// How long approvals usually take, as the backend measures it.
  final int? typicalWaitMinutes;

  /// The value above which this approval is needed (management approvals).
  final int? thresholdCents;

  @override
  List<Object?> get props => [kind, approverName, typicalWaitMinutes, thresholdCents];
}

/// Who cancelled a request and why (Figma REQ-09).
class RequestCancellationInfo extends Equatable {
  const RequestCancellationInfo({this.cancelledBy, this.cancelledAt, this.reason, this.expiredByDeadline = false});

  final String? cancelledBy;
  final DateTime? cancelledAt;
  final String? reason;

  /// The request was cancelled automatically because the 72 h upload deadline
  /// passed (shown as "expired", not "cancelled").
  final bool expiredByDeadline;

  @override
  List<Object?> get props => [cancelledBy, cancelledAt, reason, expiredByDeadline];
}

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
    this.approval,
    this.rejectionReason,
    this.cancellation,
    this.refundedCents,
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

  /// Who must approve (pending approval statuses only).
  final RequestApprovalInfo? approval;

  /// The authority's reason (rejected requests).
  final String? rejectionReason;

  /// Who / when / why (cancelled requests).
  final RequestCancellationInfo? cancellation;

  /// The held amount returned to the wallet (rejected / cancelled requests).
  final int? refundedCents;

  bool get isCancellable => _cancellableStatuses.contains(status);

  bool get hasOutput => status == RequestStatus.completed;

  /// The server listed documents per traveler (Figma REQ-12).
  bool get hasTravelerDocuments => travelers.any((t) => t.documents.isNotEmpty);

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
        approval,
        rejectionReason,
        cancellation,
        refundedCents,
      ];
}
