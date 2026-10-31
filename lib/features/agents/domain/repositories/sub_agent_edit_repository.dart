import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

abstract interface class SubAgentEditRepository {
  /// Changes a sub-agency's name and/or its owner's name and sign-in e-mail
  /// (`updateAgentProfile`). Only the given fields change; the tier is never part of it.
  Future<Either<Failure, void>> update({required String agentId, String? name, String? ownerFullName, String? ownerEmail});
}
