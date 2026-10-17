import 'package:equatable/equatable.dart';

enum HelpTopic { account, requests, wallet }

/// One question of the help centre with its answer (Figma SUP-04).
class HelpArticle extends Equatable {
  const HelpArticle({required this.id, required this.topic, required this.question, required this.answer});

  final String id;
  final HelpTopic topic;
  final String question;
  final String answer;

  @override
  List<Object?> get props => [id, topic, question, answer];
}

/// The articles matching [query] (in the question or the answer, ignoring case
/// and surrounding spaces) and, when set, [topic]. Pure and local.
List<HelpArticle> filterHelpArticles(List<HelpArticle> all, {String query = '', HelpTopic? topic}) {
  final q = query.trim().toLowerCase();
  return [
    for (final a in all)
      if ((topic == null || a.topic == topic) &&
          (q.isEmpty || a.question.toLowerCase().contains(q) || a.answer.toLowerCase().contains(q)))
        a,
  ];
}
