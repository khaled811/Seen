import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/hospital.dart';

abstract interface class HospitalRepository {
  /// The hospitals of a medical service with their places left this week.
  Future<Either<Failure, List<Hospital>>> availability(String serviceId);
}
