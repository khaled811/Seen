import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

/// Changing the sign-in e-mail. The server mails a one-time link to the NEW address; the
/// change is confirmed from that link (a web page), never inside the app.
abstract interface class EmailChangeRepository {
  Future<Either<Failure, String>> currentEmail();

  /// Always succeeds for a well-formed request: the server never says whether an address is taken.
  Future<Either<Failure, void>> request({required String newEmail, required String currentPassword});
}
