import 'failure.dart';

/// Which rule the server's password check broke: the `params.rule` of `password_weak`
/// (`password_too_similar`, `password_too_short`, `password_too_common`,
/// `password_entirely_numeric`), or null when the failure has none.
String? passwordRuleOf(Failure failure) {
  if (failure is! ServerFailure || failure.code != 'password_weak') return null;
  final rule = failure.details['rule'];
  return rule is String ? rule : null;
}
