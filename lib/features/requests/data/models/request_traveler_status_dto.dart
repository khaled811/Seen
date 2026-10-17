import '../../domain/entities/request_traveler_status.dart';

class TravelerDocumentDto {
  const TravelerDocumentDto({required this.name, this.url, this.status});

  factory TravelerDocumentDto.fromJson(Map<String, dynamic> json) => TravelerDocumentDto(
        name: json['name'] as String,
        url: json['url'] as String?,
        status: json['status'] as String?,
      );

  final String name;
  final String? url;
  final String? status;

  TravelerDocument toEntity() =>
      TravelerDocument(name: name, url: url, status: TravelerDocumentStatus.fromValue(status));
}

class RequestTravelerStatusDto {
  const RequestTravelerStatusDto({
    required this.name,
    required this.status,
    this.passportNumber,
    this.documents = const [],
  });

  factory RequestTravelerStatusDto.fromJson(Map<String, dynamic> json) =>
      RequestTravelerStatusDto(
        name: json['name'] as String,
        passportNumber: json['passportNumber'] as String?,
        status: json['status'] as String?,
        documents: [
          for (final d in (json['documents'] as List<dynamic>? ?? const []))
            TravelerDocumentDto.fromJson(d as Map<String, dynamic>),
        ],
      );

  final String name;
  final String? passportNumber;
  final String? status;
  final List<TravelerDocumentDto> documents;

  RequestTravelerStatus toEntity() => RequestTravelerStatus(
        name: name,
        passportNumber: passportNumber,
        status: TravelerApprovalStatus.fromValue(status),
        documents: [for (final d in documents) d.toEntity()],
      );
}
