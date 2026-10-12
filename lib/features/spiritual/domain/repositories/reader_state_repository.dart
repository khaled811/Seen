import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/last_read.dart';
import '../entities/reader_state.dart';

/// Persisted reader state: bookmarks, last-read position, font size.
/// Every mutation is on disk by the time its future completes.
abstract interface class ReaderStateRepository {
  Future<Either<Failure, ReaderState>> load();

  /// Adds the bookmark if absent, removes it if present. Returns the
  /// resulting full state.
  Future<Either<Failure, ReaderState>> toggleBookmark(
    int surah,
    int ayah, {
    required DateTime now,
  });

  Future<Either<Failure, ReaderState>> saveLastRead(LastRead lastRead);
  Future<Either<Failure, ReaderState>> saveFontStep(int step);
}
