import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/agency_registration.dart';
import '../models/registration_challenge_dto.dart';
import 'agency_registration_remote_data_source.dart';

/// DEBUG ONLY: decorates the real data source and, when a real call fails in a
/// debug build, answers with canned results so the registration flow (and its
/// error states) can be tried before the backend exists. `kDebugMode` is a
/// compile-time constant, so release builds drop every fallback branch.
///
/// Demo rules: a phone ending `0722` is rate limited (4:59); a phone ending
/// `0733` is "already registered" (reported when the code is verified, as in the
/// design). The code `123456` is correct, `000000` is expired, any other code is
/// wrong (3 tries, then locked).
class DebugFallbackAgencyRegistrationRemoteDataSource implements AgencyRegistrationRemoteDataSource {
  DebugFallbackAgencyRegistrationRemoteDataSource(this._real);

  final AgencyRegistrationRemoteDataSource _real;
  int _triesLeft = 3;
  bool _phoneTaken = false;

  static const _challenge = RegistrationChallengeDto(
    challengeToken: 'debug-registration',
    maskedPhone: '+967 77 ••• 0700',
    resendCooldownSeconds: 45,
  );

  @override
  Future<Either<Failure, RegistrationChallengeDto>> start({
    required AgencyRegistrationDraft draft,
    required String password,
  }) async {
    final result = await _real.start(draft: draft, password: password);
    if (!(kDebugMode && result.isLeft())) return result;
    _triesLeft = 3;
    _phoneTaken = draft.phone.endsWith('0733');
    if (draft.phone.endsWith('0722')) {
      return const Left(
        ServerFailure('Rate limited', code: RegistrationIssue.rateLimitedCode, details: {'retryAfterSeconds': 299}),
      );
    }
    return const Right(_challenge);
  }

  @override
  Future<Either<Failure, RegistrationChallengeDto>> resendCode({required String challengeToken}) async {
    final result = await _real.resendCode(challengeToken: challengeToken);
    if (!(kDebugMode && result.isLeft())) return result;
    _triesLeft = 3;
    return const Right(_challenge);
  }

  @override
  Future<Either<Failure, String>> verifyPhone({required String challengeToken, required String code}) async {
    final result = await _real.verifyPhone(challengeToken: challengeToken, code: code);
    if (!(kDebugMode && result.isLeft())) return result;
    if (code == '123456') {
      if (_phoneTaken) {
        return const Left(ServerFailure('Phone taken', code: RegistrationIssue.phoneTakenCode));
      }
      return const Right('debug-verification');
    }
    if (code == '000000') return const Left(ServerFailure('Expired', code: RegistrationIssue.expiredCodeCode));
    _triesLeft--;
    if (_triesLeft <= 0) {
      return const Left(
        ServerFailure('Exhausted', code: RegistrationIssue.exhaustedCode, details: {'lockoutMinutes': 15}),
      );
    }
    return Left(
      ServerFailure('Wrong code', code: RegistrationIssue.wrongCodeCode, details: {'attemptsLeft': _triesLeft}),
    );
  }

  @override
  Future<Either<Failure, void>> complete({
    required String verificationToken,
    required RegistrationConsent consent,
  }) async {
    final result = await _real.complete(verificationToken: verificationToken, consent: consent);
    if (!(kDebugMode && result.isLeft())) return result;
    return const Right(null);
  }
}
