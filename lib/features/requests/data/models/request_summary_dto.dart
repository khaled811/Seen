import '../../../../core/constants/enums.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/request_summary.dart';

/// Wire shape of one Requests Dashboard row.
///
/// TODO(backend-contract): field names are placeholders pending the real
/// Seen Booking GraphQL schema — update here and in
/// `requests_remote_data_source.dart` once confirmed.
class RequestSummaryDto {
  const RequestSummaryDto({
    required this.id,
    required this.referenceId,
    required this.serviceName,
    required this.travelerCount,
    required this.totalPriceAmount,
    required this.status,
    required this.submittedAt,
    this.slaDeadline,
    this.rejectionNote,
    this.travelerNames = const [],
  });

  factory RequestSummaryDto.fromJson(Map<String, dynamic> json) => RequestSummaryDto(
        id: json['id'] as String,
        referenceId: json['referenceId'] as String,
        serviceName: json['serviceName'] as String,
        travelerCount: json['travelerCount'] as int,
        totalPriceAmount: json['totalPriceAmount'] as String,
        status: json['status'] as String?,
        submittedAt: DateTime.parse(json['submittedAt'] as String),
        slaDeadline: json['slaDeadline'] == null
            ? null
            : DateTime.parse(json['slaDeadline'] as String),
        rejectionNote: json['rejectionNote'] as String?,
        travelerNames: [
          for (final n in (json['travelerNames'] as List<dynamic>? ?? const [])) n as String,
        ],
      );

  final String id;
  final String referenceId;
  final String serviceName;
  final int travelerCount;

  /// Decimal string (e.g. `"450.00"`) — never parsed as `double`.
  final String totalPriceAmount;
  final String? status;
  final DateTime submittedAt;
  final DateTime? slaDeadline;
  final String? rejectionNote;

  /// TODO(backend-contract): placeholder (docs/BACKEND_MIGRATION_GAPS.md, section 22).
  final List<String> travelerNames;

  RequestSummary toEntity() => RequestSummary(
        id: id,
        referenceId: referenceId,
        serviceName: serviceName,
        travelerCount: travelerCount,
        totalPriceCents: MoneyParser.centsFromDecimalString(totalPriceAmount),
        status: RequestStatus.fromValue(status),
        submittedAt: submittedAt,
        slaDeadline: slaDeadline,
        rejectionNote: rejectionNote,
        travelerNames: travelerNames,
      );
}
