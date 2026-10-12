import '../../../../core/constants/enums.dart';
import '../../domain/entities/request_timeline_entry.dart';

class RequestTimelineEntryDto {
  const RequestTimelineEntryDto({
    required this.status,
    required this.occurredAt,
    this.note,
  });

  factory RequestTimelineEntryDto.fromJson(Map<String, dynamic> json) =>
      RequestTimelineEntryDto(
        status: json['status'] as String?,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        note: json['note'] as String?,
      );

  final String? status;
  final DateTime occurredAt;
  final String? note;

  RequestTimelineEntry toEntity() => RequestTimelineEntry(
        status: RequestStatus.fromValue(status),
        occurredAt: occurredAt,
        note: note,
      );
}
