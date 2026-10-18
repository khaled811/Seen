import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/manifest.dart';

abstract interface class ManifestRepository {
  /// The agent's open manifest for [serviceId] (created when there is none).
  Future<Either<Failure, ManifestDraft>> openDraft(
      {required String serviceId, required String serviceLabel});

  Future<Either<Failure, ManifestDraft>> addTraveler({
    required String draftId,
    required String name,
    String? passportNumber,
  });

  /// Adds the rows of a spreadsheet; the server answers with the whole manifest.
  Future<Either<Failure, ManifestDraft>> importList(
      {required String draftId, required ManifestImportFile file});

  Future<Either<Failure, void>> saveDraft(String draftId);

  /// Sends the manifest; resolves the id of its summary. Incomplete travelers are not sent.
  Future<Either<Failure, String>> submit(String draftId);

  Future<Either<Failure, ManifestSummary>> summary(String manifestId);

  /// Sends a rejected traveler again.
  Future<Either<Failure, ManifestSummary>> resubmit(
      {required String manifestId, required String travelerId});

  /// Where the issued visas of the manifest can be downloaded (one archive).
  Future<Either<Failure, String>> issuedVisasUrl(String manifestId);
}

/// Picks a spreadsheet from the device. null = cancelled.
abstract interface class ManifestImportPicker {
  Future<Either<Failure, ManifestImportFile?>> pick();
}
