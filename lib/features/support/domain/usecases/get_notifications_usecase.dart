import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/in_app_notification.dart';
import '../repositories/support_repository.dart';

class GetNotificationsUseCase {
  const GetNotificationsUseCase(this._repository);

  final SupportRepository _repository;

  Future<Either<Failure, List<InAppNotification>>> call() =>
      _repository.getNotifications();
}
