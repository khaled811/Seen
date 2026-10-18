import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

/// "Tell me when this service launches" (Figma BOOK-09).
abstract interface class ServiceInterestRepository {
  /// Registers the agency's interest in the not-yet-bookable service [serviceKey]; the
  /// server should answer success again for a repeat.
  Future<Either<Failure, void>> notifyWhenAvailable(String serviceKey);

  /// Already registered during this run of the app (so the sheet can say so).
  bool alreadyRequested(String serviceKey);
}
