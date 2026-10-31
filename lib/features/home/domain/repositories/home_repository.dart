import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/home_service.dart';

abstract interface class HomeRepository {
  /// The services the server puts first on the home screen (at most [limit]).
  Future<Either<Failure, List<HomeService>>> services({int limit = 6});
}
