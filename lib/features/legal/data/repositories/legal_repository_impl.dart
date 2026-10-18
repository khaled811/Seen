import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/legal_document.dart';
import '../../domain/repositories/legal_repository.dart';
import '../datasources/legal_data_sources.dart';

class LegalRepositoryImpl implements LegalRepository {
  LegalRepositoryImpl({required LegalRemoteDataSource remote, required LegalCache cache})
      : _remote = remote,
        _cache = cache;

  final LegalRemoteDataSource _remote;
  final LegalCache _cache;

  @override
  Future<Either<Failure, LegalResult>> get(LegalKind kind, LegalLanguage language) async {
    final fresh = await _remote.fetch(kind, language);
    final doc = fresh.toNullable();
    if (doc != null) {
      await _cache.write(doc);
      return Right(LegalResult(doc));
    }
    final saved = await _cache.read(kind, language);
    if (saved != null) {
      return Right(LegalResult(saved, fromCache: true));
    }
    return Left(fresh.swap().getOrElse((_) => const ServerFailure('legal text unavailable')));
  }
}
