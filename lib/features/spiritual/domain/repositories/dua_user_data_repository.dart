import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/dua_filter.dart';
import '../entities/dua_user_data.dart';

abstract interface class DuaUserDataRepository {
  Future<Either<Failure, DuaUserData>> load();

  /// Adds [id] to the favourites, or removes it when already there.
  Future<Either<Failure, DuaUserData>> toggleFavorite(String id);

  Future<Either<Failure, DuaUserData>> saveFilter(DuaFilter filter);
}
