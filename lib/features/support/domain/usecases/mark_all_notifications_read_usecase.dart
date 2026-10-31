import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/support_repository.dart';

class MarkAllNotificationsReadUseCase {
  const MarkAllNotificationsReadUseCase(this._repository);

  final SupportRepository _repository;

  /// How many notifications were marked read.
  Future<Either<Failure, int>> call() => _repository.markAllNotificationsRead();
}
