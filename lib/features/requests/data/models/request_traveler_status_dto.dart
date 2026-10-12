import '../../domain/entities/request_traveler_status.dart';

class RequestTravelerStatusDto {
  const RequestTravelerStatusDto({
    required this.name,
    required this.status,
    this.passportNumber,
  });

  factory RequestTravelerStatusDto.fromJson(Map<String, dynamic> json) =>
      RequestTravelerStatusDto(
        name: json['name'] as String,
        passportNumber: json['passportNumber'] as String?,
        status: json['status'] as String?,
      );

  final String name;
  final String? passportNumber;
  final String? status;

  RequestTravelerStatus toEntity() => RequestTravelerStatus(
        name: name,
        passportNumber: passportNumber,
        status: TravelerApprovalStatus.fromValue(status),
      );
}
