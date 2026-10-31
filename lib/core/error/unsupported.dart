import 'package:fpdart/fpdart.dart';

import 'failure.dart';

/// The code of the failure a feature returns for an operation the API does not
/// offer (contract section 14, DECISIONS P-06). The UI turns it into the
/// "not available yet" text; nothing is sent and nothing is faked.
const String unsupportedOperationCode = 'unsupported_operation';

/// Whether [failure] says the API has no such operation (a screen then explains that
/// instead of offering a retry that can never work).
bool isUnsupportedFailure(Failure failure) => failure is ServerFailure && failure.code == unsupportedOperationCode;

/// `Left` of an operation the contract does not have. [what] names it for the
/// developer (never shown to the user).
Either<Failure, T> unsupportedOperation<T>(String what) =>
    Left(ServerFailure('$what is not offered by the API.', code: unsupportedOperationCode));
