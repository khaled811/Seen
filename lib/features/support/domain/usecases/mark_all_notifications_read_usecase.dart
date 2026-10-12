import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/support_repository.dart';

/// Not named in Task 10's own use-case list, but required to fulfil its
/// business rule #2 ("Mark all as read").
class MarkAllNotificationsReadUseCase {
  const MarkAllNotificationsReadUseCase(this._repository);

  final SupportRepository _repository;

  Future<Either<Failure, void>> call() => _repository.markAllNotificationsRead();
}
