import '../../domain/entities/missing_document.dart';

/// Wire shape of the "missing document" query.
///
/// TODO(backend-contract): field names are placeholders (docs/BACKEND_MIGRATION_GAPS.md, section 10).
class MissingDocumentDto {
  const MissingDocumentDto({
    required this.requestId,
    required this.referenceId,
    required this.documentTitle,
    required this.reason,
    required this.deadline,
    this.travelerName,
    this.maxBytes,
    this.allowedExtensions,
  });

  factory MissingDocumentDto.fromJson(Map<String, dynamic> json) => MissingDocumentDto(
        requestId: json['requestId'] as String,
        referenceId: json['referenceId'] as String,
        documentTitle: json['documentTitle'] as String,
        travelerName: json['travelerName'] as String?,
        reason: json['reason'] as String? ?? '',
        deadline: DateTime.parse(json['deadline'] as String),
        maxBytes: json['maxBytes'] as int?,
        allowedExtensions: (json['allowedExtensions'] as List<dynamic>?)?.map((e) => '$e'.toLowerCase()).toList(),
      );

  final String requestId;
  final String referenceId;
  final String documentTitle;
  final String? travelerName;
  final String reason;
  final DateTime deadline;
  final int? maxBytes;
  final List<String>? allowedExtensions;

  MissingDocumentRequest toEntity() => MissingDocumentRequest(
        requestId: requestId,
        referenceId: referenceId,
        documentTitle: documentTitle,
        travelerName: travelerName,
        reason: reason,
        deadline: deadline,
        maxBytes: maxBytes ?? 5 * 1024 * 1024,
        allowedExtensions: allowedExtensions ?? const ['jpg', 'jpeg', 'png', 'pdf'],
      );
}
