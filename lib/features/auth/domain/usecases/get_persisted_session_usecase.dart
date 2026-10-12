import '../entities/user_session.dart';
import '../repositories/auth_repository.dart';

/// Used on app bootstrap to restore a previously authenticated session
/// without a round trip to the server.
class GetPersistedSessionUseCase {
  const GetPersistedSessionUseCase(this._repository);

  final AuthRepository _repository;

  Future<UserSession?> call() => _repository.getPersistedSession();
}
