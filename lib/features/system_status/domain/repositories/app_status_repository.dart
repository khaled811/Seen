import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/app_status.dart';

abstract interface class AppStatusRepository {
  /// Public (works before sign-in).
  Future<Either<Failure, AppStatus>> fetch();
}
