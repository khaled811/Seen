import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/ad_banner.dart';

abstract interface class AdsRepository {
  /// The first ad the server offers for the home banner, or null when it has none
  /// (a pending or suspended agency always gets none).
  Future<Either<Failure, AdBanner?>> homeBanner();

  /// Counts that the ad was shown (the server keeps one per ad per person per day) / that its
  /// button was tapped. Best effort: an ad count is never worth an error for the person.
  Future<Either<Failure, void>> recordImpression(String adId);

  Future<Either<Failure, void>> recordClick(String adId);
}
