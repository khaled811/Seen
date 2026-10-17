import '../../../../core/constants/enums.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/request_detail.dart';
import 'request_timeline_entry_dto.dart';
import 'request_traveler_status_dto.dart';

/// Wire shape of the Request Detail screen's data.
///
/// TODO(backend-contract): field names are placeholders pending the real
/// Seen Booking GraphQL schema.
class RequestDetailDto {
  const RequestDetailDto({
    required this.id,
    required this.referenceId,
    required this.serviceName,
    required this.totalPriceAmount,
    required this.submittedAt,
    required this.travelers,
    required this.timeline,
    this.status,
    this.slaDeadline,
    this.outputDocumentUrl,
    this.approval,
    this.rejectionReason,
    this.cancellation,
    this.refundedAmount,
  });

  factory RequestDetailDto.fromJson(Map<String, dynamic> json) => RequestDetailDto(
        id: json['id'] as String,
        referenceId: json['referenceId'] as String,
        serviceName: json['serviceName'] as String,
        status: json['status'] as String?,
        totalPriceAmount: json['totalPriceAmount'] as String,
        submittedAt: DateTime.parse(json['submittedAt'] as String),
        slaDeadline: json['slaDeadline'] == null
            ? null
            : DateTime.parse(json['slaDeadline'] as String),
        outputDocumentUrl: json['outputDocumentUrl'] as String?,
        approval: json['approval'] == null
            ? null
            : RequestApprovalDto.fromJson(json['approval'] as Map<String, dynamic>),
        rejectionReason: json['rejectionReason'] as String?,
        cancellation: json['cancellation'] == null
            ? null
            : RequestCancellationDto.fromJson(json['cancellation'] as Map<String, dynamic>),
        refundedAmount: json['refundedAmount'] as String?,
        travelers: (json['travelers'] as List<dynamic>)
            .map((e) => RequestTravelerStatusDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        timeline: (json['timeline'] as List<dynamic>)
            .map((e) => RequestTimelineEntryDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String referenceId;
  final String serviceName;
  final String? status;

  /// Decimal string (e.g. `"450.00"`) — never parsed as `double`.
  final String totalPriceAmount;
  final DateTime submittedAt;
  final DateTime? slaDeadline;
  final String? outputDocumentUrl;
  final RequestApprovalDto? approval;
  final String? rejectionReason;
  final RequestCancellationDto? cancellation;

  /// Decimal string.
  final String? refundedAmount;
  final List<RequestTravelerStatusDto> travelers;
  final List<RequestTimelineEntryDto> timeline;

  RequestDetail toEntity() => RequestDetail(
        id: id,
        referenceId: referenceId,
        serviceName: serviceName,
        status: RequestStatus.fromValue(status),
        totalPriceCents: MoneyParser.centsFromDecimalString(totalPriceAmount),
        submittedAt: submittedAt,
        slaDeadline: slaDeadline,
        outputDocumentUrl: outputDocumentUrl,
        approval: approval?.toEntity(),
        rejectionReason: rejectionReason,
        cancellation: cancellation?.toEntity(),
        refundedCents: refundedAmount == null ? null : MoneyParser.centsFromDecimalString(refundedAmount!),
        travelers: travelers.map((dto) => dto.toEntity()).toList(),
        timeline: timeline.map((dto) => dto.toEntity()).toList(),
      );
}

/// Wire shape of the approval info. TODO(backend-contract): placeholder names.
class RequestApprovalDto {
  const RequestApprovalDto({required this.kind, this.approverName, this.typicalWaitMinutes, this.thresholdAmount});

  factory RequestApprovalDto.fromJson(Map<String, dynamic> json) => RequestApprovalDto(
        kind: json['kind'] as String?,
        approverName: json['approverName'] as String?,
        typicalWaitMinutes: json['typicalWaitMinutes'] as int?,
        thresholdAmount: json['thresholdAmount'] as String?,
      );

  final String? kind;
  final String? approverName;
  final int? typicalWaitMinutes;
  final String? thresholdAmount;

  RequestApprovalInfo toEntity() => RequestApprovalInfo(
        kind: kind == 'MANAGEMENT' ? ApproverKind.management : ApproverKind.masterAgent,
        approverName: approverName,
        typicalWaitMinutes: typicalWaitMinutes,
        thresholdCents: thresholdAmount == null ? null : MoneyParser.centsFromDecimalString(thresholdAmount!),
      );
}

class RequestCancellationDto {
  const RequestCancellationDto({this.cancelledBy, this.cancelledAt, this.reason, this.code});

  factory RequestCancellationDto.fromJson(Map<String, dynamic> json) => RequestCancellationDto(
        cancelledBy: json['cancelledBy'] as String?,
        cancelledAt: json['cancelledAt'] == null ? null : DateTime.parse(json['cancelledAt'] as String),
        reason: json['reason'] as String?,
        code: json['code'] as String?,
      );

  final String? cancelledBy;
  final DateTime? cancelledAt;
  final String? reason;

  /// `DEADLINE_EXPIRED` for an automatic cancellation.
  final String? code;

  RequestCancellationInfo toEntity() => RequestCancellationInfo(
        cancelledBy: cancelledBy,
        cancelledAt: cancelledAt,
        reason: reason,
        expiredByDeadline: code == 'DEADLINE_EXPIRED',
      );
}
