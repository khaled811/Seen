import 'package:equatable/equatable.dart';

/// Where the agency stands with Jubari's verification (Figma ACC-01).
enum AgencyVerification { verified, pending, rejected, unverified }

enum AgencyDocumentKind { commercialRegister, tourismLicense, other }

/// How close a document is to the end of its validity.
enum DocumentExpiry { none, valid, soon, expired }

/// Documents expiring within this many days are flagged ("expires in 23 days").
const documentExpiryWarningDays = 30;

class AgencyDocument extends Equatable {
  const AgencyDocument({required this.id, required this.kind, this.expiresAt, this.viewUrl});

  final String id;
  final AgencyDocumentKind kind;
  final DateTime? expiresAt;

  /// Where the file can be opened (server-provided); null = nothing to open.
  final String? viewUrl;

  /// Whole days left on [today]'s date; negative once expired; null without an expiry.
  int? daysLeft(DateTime today) {
    final e = expiresAt;
    if (e == null) return null;
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(e.year, e.month, e.day);
    return b.difference(a).inDays;
  }

  DocumentExpiry expiry(DateTime today) {
    final left = daysLeft(today);
    if (left == null) return DocumentExpiry.none;
    if (left < 0) return DocumentExpiry.expired;
    if (left <= documentExpiryWarningDays) return DocumentExpiry.soon;
    return DocumentExpiry.valid;
  }

  @override
  List<Object?> get props => [id, kind, expiresAt, viewUrl];
}

class AgencyProfile extends Equatable {
  const AgencyProfile({
    required this.name,
    required this.licenseNumber,
    required this.city,
    required this.managerName,
    required this.verification,
    this.verifiedAt,
    this.documents = const [],
  });

  final String name;
  final String licenseNumber;
  final String city;
  final String managerName;
  final AgencyVerification verification;
  final DateTime? verifiedAt;
  final List<AgencyDocument> documents;

  @override
  List<Object?> get props => [name, licenseNumber, city, managerName, verification, verifiedAt, documents];
}
