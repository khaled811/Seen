import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/auth/domain/repositories/email_change_repository.dart';

/// A scripted [EmailChangeRepository]; set the answers, read the calls.
class FakeEmailChangeRepository implements EmailChangeRepository {
  Either<Failure, String> currentResult = const Right('owner@agency.com');
  Either<Failure, void> requestResult = const Right(null);

  /// When set, `request` waits for it (to see the "sending" state).
  Completer<void>? hold;

  final requests = <({String newEmail, String password})>[];

  @override
  Future<Either<Failure, String>> currentEmail() async => currentResult;

  @override
  Future<Either<Failure, void>> request({required String newEmail, required String currentPassword}) async {
    requests.add((newEmail: newEmail, password: currentPassword));
    await hold?.future;
    return requestResult;
  }
}
