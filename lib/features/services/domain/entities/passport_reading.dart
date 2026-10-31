import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// One value the server read from the passport's data page. It is only a suggestion: the person
/// confirms it before it goes into the traveler form, and nothing is submitted silently.
class PassportSuggestion extends Equatable {
  const PassportSuggestion({required this.key, required this.value, required this.checked});

  /// The form field it belongs to.
  final String key;
  final String value;

  /// The server's own verdict: false = it is not sure of this reading.
  final bool checked;

  @override
  List<Object?> get props => [key, value, checked];
}

class PassportReading extends Equatable {
  const PassportReading({required this.suggestions, required this.allChecksPass});

  final List<PassportSuggestion> suggestions;
  final bool allChecksPass;

  @override
  List<Object?> get props => [suggestions, allChecksPass];
}

enum PassportIssueKind { notImage, unavailable, unreadable, rateLimited, tooLarge, offline, forbidden, generic }

class PassportIssue extends Equatable {
  const PassportIssue(this.kind);

  final PassportIssueKind kind;

  /// Codes of the contract (guide 8.3 and the file errors).
  static const notImageCode = 'passport_not_image';
  static const unavailableCode = 'ocr_unavailable';

  factory PassportIssue.from(Failure failure) {
    if (failure is NetworkFailure) {
      return const PassportIssue(PassportIssueKind.offline);
    }
    if (failure is ForbiddenFailure) {
      return const PassportIssue(PassportIssueKind.forbidden);
    }
    if (failure is ServerFailure) {
      return switch (failure.code) {
        notImageCode || 'file_type_not_allowed' || 'file_content_mismatch' || 'file_empty' => const PassportIssue(PassportIssueKind.notImage),
        unavailableCode => const PassportIssue(PassportIssueKind.unavailable),
        'too_many_attempts' => const PassportIssue(PassportIssueKind.rateLimited),
        'file_too_large' => const PassportIssue(PassportIssueKind.tooLarge),
        _ => const PassportIssue(PassportIssueKind.generic),
      };
    }
    return const PassportIssue(PassportIssueKind.generic);
  }

  @override
  List<Object?> get props => [kind];
}
