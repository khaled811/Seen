import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/reader_view_prefs.dart';
import '../repositories/reader_view_prefs_repository.dart';

class LoadReaderViewPrefsUseCase {
  const LoadReaderViewPrefsUseCase(this._repository);

  final ReaderViewPrefsRepository _repository;

  Future<Either<Failure, ReaderViewPrefs>> call() => _repository.load();
}

class SaveReaderViewPrefsUseCase {
  const SaveReaderViewPrefsUseCase(this._repository);

  final ReaderViewPrefsRepository _repository;

  Future<Either<Failure, ReaderViewPrefs>> call(ReaderViewPrefs prefs) =>
      _repository.save(prefs);
}
