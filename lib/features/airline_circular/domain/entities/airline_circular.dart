import 'package:equatable/equatable.dart';

/// An issued security approval a circular can be linked to (Figma REQ-15).
class ApprovedSecurityRequest extends Equatable {
  const ApprovedSecurityRequest({
    required this.id,
    required this.reference,
    required this.leadName,
    required this.travelerCount,
    required this.issuedAt,
  });

  final String id;

  /// e.g. "SB-20451".
  final String reference;
  final String leadName;
  final int travelerCount;
  final DateTime issuedAt;

  @override
  List<Object?> get props => [id, reference, leadName, travelerCount, issuedAt];
}

/// A traveler of the approval, copied into the circular and locked.
class CircularTraveler extends Equatable {
  const CircularTraveler({required this.name, required this.passportNumber});

  final String name;
  final String passportNumber;

  @override
  List<Object?> get props => [name, passportNumber];
}

class CircularPrefill extends Equatable {
  const CircularPrefill({required this.approval, required this.travelers});

  final ApprovedSecurityRequest approval;
  final List<CircularTraveler> travelers;

  @override
  List<Object?> get props => [approval, travelers];
}

/// The flight ticket: the only document a circular needs.
class CircularTicket extends Equatable {
  const CircularTicket(
      {required this.path, required this.fileName, required this.sizeBytes});

  final String path;
  final String fileName;
  final int sizeBytes;

  @override
  List<Object?> get props => [path, fileName, sizeBytes];
}

class CircularSubmission extends Equatable {
  const CircularSubmission({
    required this.approvalId,
    required this.ticket,
    required this.flightNumber,
    required this.flightDate,
  });

  final String approvalId;
  final CircularTicket ticket;

  /// Upper case, e.g. "RJ 615".
  final String flightNumber;
  final DateTime flightDate;

  @override
  List<Object?> get props => [approvalId, ticket, flightNumber, flightDate];
}

/// "RJ 615", "RJ615", "QR1203": two characters for the airline (at least one a letter), then 1 to 4 digits.
final _flightNumberPattern = RegExp(r'^(?=[A-Z0-9]?[A-Z])[A-Z0-9]{2}\s?\d{1,4}$');

/// Upper-cases and trims; null when it is not a plausible flight number.
String? normalizeFlightNumber(String input) {
  final v = input.trim().toUpperCase();
  return _flightNumberPattern.hasMatch(v) ? v : null;
}
