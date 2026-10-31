import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

/// How many support tickets have replies the agent has not read (`unreadTicketsCount`).
abstract interface class UnreadTicketsRepository {
  Future<Either<Failure, int>> count();
}
