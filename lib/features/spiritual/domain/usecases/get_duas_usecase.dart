import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/dua.dart';
import '../repositories/dua_repository.dart';

class GetDuasUseCase {
  const GetDuasUseCase(this._repository);

  final DuaRepository _repository;

  Future<Either<Failure, List<Dua>>> call({DuaCategory? category}) =>
      _repository.getDuas(category: category);
}
