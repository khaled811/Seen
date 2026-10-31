import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../error/failure.dart';
import '../error/password_rule.dart';

/// [localizedFailureMessage] for a failure that may be absent: the developer
/// [fallback] text is used only when there is no [failure] to localize (old
/// call sites, tests with hand-made states).
String failureTextOr(AppLocalizations l10n, Failure? failure, String fallback) =>
    failure == null ? fallback : localizedFailureMessage(l10n, failure);

/// The text for a password the server refused: it names the rule that was broken
/// (`password_too_similar`, ...); an unknown or missing rule gets the general text.
String passwordRuleMessage(AppLocalizations l10n, String? rule) => switch (rule) {
      'password_too_similar' => l10n.passwordRuleSimilar,
      'password_too_short' => l10n.passwordRuleShort,
      'password_too_common' => l10n.passwordRuleCommon,
      'password_entirely_numeric' => l10n.passwordRuleNumeric,
      _ => l10n.recoveryPasswordWeak,
    };

/// The one place that turns a [Failure] into user-facing text.
///
/// The backend contract says to branch on `extensions.code` and show the app's
/// own localized strings, never the server's message. Codes that a screen
/// handles specially are handled there; this resolver covers everything else
/// and falls back to a generic message by failure type. Add a code here when a
/// feature needs a specific message for it.
String localizedFailureMessage(AppLocalizations l10n, Failure failure) {
  final code = switch (failure) {
    ServerFailure(:final code) => code,
    UnauthorizedFailure(:final code) => code,
    ForbiddenFailure(:final code) => code,
    _ => null,
  };
  switch (code) {
    case 'otp_code_invalid':
      return l10n.otpInvalidCode;
    case 'topup_below_minimum':
      return l10n.errTopupBelowMinimum;
    case 'invalid_topup_method':
      return l10n.errInvalidTopupMethod;
    case 'payment_account_not_found':
      return l10n.errPaymentAccountNotFound;
    case 'payment_account_currency_mismatch':
      return l10n.errPaymentAccountCurrencyMismatch;
    case 'idempotency_key_reused':
      return l10n.errIdempotencyKeyReused;
    case 'file_too_large':
      return l10n.errFileTooLarge;
    case 'file_type_not_allowed':
      return l10n.errFileTypeNotAllowed;
    case 'file_content_mismatch':
      return l10n.errFileContentMismatch;
    case 'file_empty':
      return l10n.errFileEmpty;
    case 'too_many_files':
      return l10n.errTooManyFiles;
    case 'document_upload_not_allowed':
    case 'document_requirement_invalid':
      return l10n.errDocumentUploadNotAllowed;
    case 'insufficient_funds':
      return l10n.errInsufficientFunds;
    case 'password_weak':
      return passwordRuleMessage(l10n, passwordRuleOf(failure));
    case 'unsupported_operation':
      return l10n.errUnsupportedOperation;
    case 'permission_denied':
    case 'role_restricted':
      return l10n.errPermissionDenied;
    case 'too_many_attempts':
      final minutes = failure is ServerFailure ? failure.details['minutes'] : null;
      return l10n.errorTooManyAttempts('${minutes ?? 15}');
  }
  return switch (failure) {
    NetworkFailure() => l10n.errorNetwork,
    UnauthorizedFailure() => l10n.errorUnauthorized,
    ForbiddenFailure() => l10n.errorForbidden,
    ServerFailure(:final statusCode) when statusCode != null && statusCode >= 500 => l10n.errorServer,
    _ => l10n.error,
  };
}
