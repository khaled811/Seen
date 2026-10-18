import 'package:equatable/equatable.dart';

enum LegalKind { terms, privacy }

enum LegalLanguage { ar, en }

class LegalSection extends Equatable {
  const LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  List<Object?> get props => [heading, body];
}

/// A long legal text (terms of use or privacy policy) in one language, with the date it
/// was last updated (Figma AUTH-09 / 10). Pure Dart.
class LegalDocument extends Equatable {
  const LegalDocument({required this.kind, required this.language, required this.updatedAt, required this.sections});

  final LegalKind kind;
  final LegalLanguage language;
  final DateTime updatedAt;
  final List<LegalSection> sections;

  @override
  List<Object?> get props => [kind, language, updatedAt, sections];
}

/// What the repository answers: the text, and whether it is the saved copy because the
/// server could not be reached ("you are offline, showing the saved version").
class LegalResult extends Equatable {
  const LegalResult(this.document, {this.fromCache = false});

  final LegalDocument document;
  final bool fromCache;

  @override
  List<Object?> get props => [document, fromCache];
}
