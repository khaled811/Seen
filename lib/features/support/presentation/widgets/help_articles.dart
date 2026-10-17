import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/entities/help_article.dart';

/// The help centre's content, localized in the app's strings. The answers are a
/// first draft written from how the app behaves; the support team owns the
/// final wording (docs/BACKEND_MIGRATION_GAPS.md, section 29).
List<HelpArticle> helpArticles(AppLocalizations l10n) => [
      HelpArticle(
        id: 'deduction',
        topic: HelpTopic.wallet,
        question: l10n.helpFaqDeductionQ,
        answer: l10n.helpFaqDeductionA,
      ),
      HelpArticle(
        id: 'missing-document',
        topic: HelpTopic.requests,
        question: l10n.helpFaqMissingDocQ,
        answer: l10n.helpFaqMissingDocA,
      ),
      HelpArticle(
        id: 'passport-rule',
        topic: HelpTopic.requests,
        question: l10n.helpFaqPassportQ,
        answer: l10n.helpFaqPassportA,
      ),
      HelpArticle(
        id: 'sub-agent',
        topic: HelpTopic.account,
        question: l10n.helpFaqSubAgentQ,
        answer: l10n.helpFaqSubAgentA,
      ),
    ];
