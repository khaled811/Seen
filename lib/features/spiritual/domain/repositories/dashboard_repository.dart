import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/dashboard_snapshot.dart';

abstract interface class DashboardRepository {
  Future<Either<Failure, DashboardSnapshot>> load();
}
