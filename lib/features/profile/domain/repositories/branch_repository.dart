import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/branch.dart';

abstract interface class BranchRepository {
  /// Every branch with its counts, main branch first.
  Future<Either<Failure, List<Branch>>> list();

  Future<Either<Failure, List<BranchStaff>>> staff(String branchId);

  /// A new branch under the main one.
  Future<Either<Failure, Branch>> create(String name);

  /// Puts [memberId] in [branchId] (assigning or moving: the server treats both the same).
  Future<Either<Failure, void>> assign({required String memberId, required String branchId});
}
