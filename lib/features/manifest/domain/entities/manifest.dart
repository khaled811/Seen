import 'package:equatable/equatable.dart';

/// Why a traveler of a manifest is not ready to be sent (decided by the server).
enum ManifestProblem { none, missingPassport, passportExpiring }

/// One line of a manifest being built (Figma REQ-14).
class ManifestTraveler extends Equatable {
  const ManifestTraveler({
    required this.id,
    required this.name,
    this.passportNumber,
    this.problem = ManifestProblem.none,
    this.monthsLeft,
  });

  final String id;
  final String name;
  final String? passportNumber;
  final ManifestProblem problem;

  /// Months of passport validity left, when [problem] is [ManifestProblem.passportExpiring].
  final int? monthsLeft;

  bool get isReady => problem == ManifestProblem.none;

  @override
  List<Object?> get props => [id, name, passportNumber, problem, monthsLeft];
}

/// A manifest being built: any number of travelers, for one service.
class ManifestDraft extends Equatable {
  const ManifestDraft(
      {required this.id, required this.serviceLabel, required this.travelers});

  final String id;

  /// e.g. "Saudi visa · Umrah".
  final String serviceLabel;
  final List<ManifestTraveler> travelers;

  int get readyCount => travelers.where((t) => t.isReady).length;
  int get incompleteCount => travelers.length - readyCount;

  @override
  List<Object?> get props => [id, serviceLabel, travelers];
}

/// Where one traveler of a sent manifest stands. Each traveler has their own status.
enum ManifestOutcome { issued, atAuthority, rejected }

class ManifestTravelerStatus extends Equatable {
  const ManifestTravelerStatus({
    required this.id,
    required this.name,
    required this.outcome,
    this.doneSteps = 0,
    this.rejectionReason,
  });

  final String id;
  final String name;
  final ManifestOutcome outcome;

  /// Steps of the visa journey done, 0..[totalSteps].
  final int doneSteps;
  final String? rejectionReason;

  static const totalSteps = 5;

  @override
  List<Object?> get props => [id, name, outcome, doneSteps, rejectionReason];
}

/// A sent manifest with a status per traveler (Figma REQ-14b).
class ManifestSummary extends Equatable {
  const ManifestSummary({
    required this.id,
    required this.reference,
    required this.title,
    required this.travelers,
  });

  final String id;

  /// e.g. "GM-0412".
  final String reference;
  final String title;
  final List<ManifestTravelerStatus> travelers;

  int count(ManifestOutcome o) => travelers.where((t) => t.outcome == o).length;

  @override
  List<Object?> get props => [id, reference, title, travelers];
}

/// A spreadsheet picked for import.
class ManifestImportFile extends Equatable {
  const ManifestImportFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  @override
  List<Object?> get props => [name, bytes.length];
}

/// Largest spreadsheet taken for import.
const manifestImportMaxBytes = 5 * 1024 * 1024;

/// Failure code of a spreadsheet over [manifestImportMaxBytes].
const manifestImportTooLargeCode = 'MANIFEST_IMPORT_TOO_LARGE';
