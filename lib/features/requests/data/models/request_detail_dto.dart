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
        travelers: travelers.map((dto) => dto.toEntity()).toList(),
        timeline: timeline.map((dto) => dto.toEntity()).toList(),
      );
}
