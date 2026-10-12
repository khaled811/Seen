import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/last_read.dart';
import '../entities/quran_data.dart';
import '../entities/reader_state.dart';
import '../repositories/quran_repository.dart';
import '../repositories/reader_state_repository.dart';

class LoadQuranUseCase {
  const LoadQuranUseCase(this._repository);

  final QuranRepository _repository;

  Future<Either<Failure, QuranData>> call() => _repository.load();
}

class GetReaderStateUseCase {
  const GetReaderStateUseCase(this._repository);

  final ReaderStateRepository _repository;

  Future<Either<Failure, ReaderState>> call() => _repository.load();
}

class ToggleBookmarkUseCase {
  const ToggleBookmarkUseCase(this._repository);

  final ReaderStateRepository _repository;

  Future<Either<Failure, ReaderState>> call(
    int surah,
    int ayah, {
    required DateTime now,
  }) =>
      _repository.toggleBookmark(surah, ayah, now: now);
}

class SaveLastReadUseCase {
  const SaveLastReadUseCase(this._repository);

  final ReaderStateRepository _repository;

  Future<Either<Failure, ReaderState>> call(LastRead lastRead) =>
      _repository.saveLastRead(lastRead);
}

class SaveFontStepUseCase {
  const SaveFontStepUseCase(this._repository);

  final ReaderStateRepository _repository;

  Future<Either<Failure, ReaderState>> call(int step) =>
      _repository.saveFontStep(step);
}
