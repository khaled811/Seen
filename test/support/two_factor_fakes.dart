import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/auth/domain/entities/two_factor.dart';
import 'package:seen_booking/features/auth/domain/repositories/two_factor_repository.dart';

const testTwoFactorSetup = TwoFactorSetup(secret: 'JBSWY3DPEHPK3PXP', provisioningUri: 'otpauth://totp/Seen:me?secret=JBSWY3DPEHPK3PXP');

const testRecoveryCodes = [
  'AAAA-0001', 'AAAA-0002', 'AAAA-0003', 'AAAA-0004', 'AAAA-0005', 'AAAA-0006', 'AAAA-0007', 'AAAA-0008', //
];

/// A scripted [TwoFactorRepository]; set the answers, read the calls.
class FakeTwoFactorRepository implements TwoFactorRepository {
  Either<Failure, TwoFactorStatus> statusResult = const Right(TwoFactorStatus(enabled: false, enrolled: false, recoveryCodesLeft: 0));
  Either<Failure, TwoFactorSetup> beginResult = const Right(testTwoFactorSetup);
  Either<Failure, List<String>> confirmResult = const Right(testRecoveryCodes);
  Either<Failure, List<String>> regenerateResult = const Right(testRecoveryCodes);

  /// When set, `confirm` and `regenerateRecoveryCodes` wait for it (to see the "verifying" state).
  Completer<void>? hold;

  int statusCalls = 0;
  int beginCalls = 0;
  final confirmed = <String>[];
  final regenerated = <String>[];

  @override
  Future<Either<Failure, TwoFactorStatus>> status() async {
    statusCalls++;
    return statusResult;
  }

  @override
  Future<Either<Failure, TwoFactorSetup>> begin() async {
    beginCalls++;
    return beginResult;
  }

  @override
  Future<Either<Failure, List<String>>> confirm(String code) async {
    confirmed.add(code);
    await hold?.future;
    return confirmResult;
  }

  @override
  Future<Either<Failure, List<String>>> regenerateRecoveryCodes(String code) async {
    regenerated.add(code);
    await hold?.future;
    return regenerateResult;
  }
}
