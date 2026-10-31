import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/in_app_notification.dart';
import '../repositories/support_repository.dart';

class GetNotificationsUseCase {
  const GetNotificationsUseCase(this._repository);

  final SupportRepository _repository;

  /// One page of the feed; [unreadOnly] is filtered by the server.
  Future<Either<Failure, NotificationsPage>> call({bool unreadOnly = false, int limit = 20, int offset = 0}) =>
      _repository.getNotifications(unreadOnly: unreadOnly, limit: limit, offset: offset);
}

class GetUnreadNotificationCountUseCase {
  const GetUnreadNotificationCountUseCase(this._repository);

  final SupportRepository _repository;

  Future<Either<Failure, int>> call() => _repository.getUnreadNotificationCount();
}
