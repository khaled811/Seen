import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/legal_document.dart';

abstract interface class LegalRepository {
  /// The server's current text; when it cannot be reached, the last saved copy (marked
  /// `fromCache`); a failure only when there is neither. Public (works before sign-in).
  Future<Either<Failure, LegalResult>> get(LegalKind kind, LegalLanguage language);
}

/// The device's saved copies of the texts.
abstract interface class LegalCache {
  Future<LegalDocument?> read(LegalKind kind, LegalLanguage language);

  Future<void> write(LegalDocument document);
}
