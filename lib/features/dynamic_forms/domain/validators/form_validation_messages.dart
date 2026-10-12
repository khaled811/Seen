/// Localized validation message strings, injected from the presentation
/// layer (built from `AppLocalizations`).
///
/// Keeping this a plain Dart class — rather than reaching for
/// `AppLocalizations` directly inside the validator — is what keeps
/// [DynamicFieldValidator] pure Dart and unit-testable without Flutter.
class FormValidationMessages {
  const FormValidationMessages({
    required this.required,
    required this.invalidEmail,
    required this.invalidPhone,
    required this.invalidNumber,
    required this.invalidDate,
    required this.invalidSelection,
    required this.tooShort,
    required this.tooLong,
    required this.numberTooSmall,
    required this.numberTooLarge,
    required this.expiryTooSoon,
    required this.dateInFuture,
  });

  final String required;
  final String invalidEmail;
  final String invalidPhone;
  final String invalidNumber;
  final String invalidDate;
  final String invalidSelection;
  final String Function(int min) tooShort;
  final String Function(int max) tooLong;
  final String Function(num min) numberTooSmall;
  final String Function(num max) numberTooLarge;
  final String Function(int months) expiryTooSoon;
  final String Function(String fieldLabel) dateInFuture;
}
