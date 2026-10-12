import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/support_repository.dart';

class MarkNotificationReadUseCase {
  const MarkNotificationReadUseCase(this._repository);

  final SupportRepository _repository;

  Future<Either<Failure, void>> call(String notificationId) =>
      _repository.markNotificationRead(notificationId);
}
