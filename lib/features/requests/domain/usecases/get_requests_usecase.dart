import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/requests_page.dart';
import '../repositories/requests_repository.dart';

class GetRequestsUseCase {
  const GetRequestsUseCase(this._repository);

  final RequestsRepository _repository;

  /// One page of requests. [group] is a [RequestsGroup] wire value.
  Future<Either<Failure, RequestsPage>> call({
    String group = 'all',
    String? search,
    int offset = 0,
    int limit = 30,
  }) =>
      _repository.getRequests(group: group, search: search, offset: offset, limit: limit);
}
