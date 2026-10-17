// Help centre (Figma SUP-04): a search box, three topics and the frequently asked
// questions, each opening in place. "No results?" leads to the support tickets.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/search_field.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/help_article.dart';
import '../widgets/help_articles.dart';
import 'support_tickets_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key, this.onContactSupport});

  /// Test seam: what "no results? contact support" does (defaults to the tickets).
  final void Function(BuildContext context)? onContactSupport;

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  // Owned here, disposed in dispose(). Filtering is local: no server round trip.
  final _search = TextEditingController();
  HelpTopic? _topic;
  String? _openId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _contact(BuildContext context) => (widget.onContactSupport ??
      (ctx) => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const SupportTicketsScreen())))(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final articles = helpArticles(l10n);
    final shown = filterHelpArticles(articles, query: _search.text, topic: _topic);
    final topics = {
      HelpTopic.wallet: (l10n.helpTopicWallet, SeenVectors.walletIcon),
      HelpTopic.requests: (l10n.helpTopicRequests, SeenVectors.iconRequests),
      HelpTopic.account: (l10n.helpTopicAccount, SeenVectors.accountAgents),
    };
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SeenScreenHeader(title: l10n.helpCenterTitle),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, SeenSpace.s1, 20, SeenSpace.s6),
                  children: [
                    SeenSearchField(
                      hint: l10n.helpSearchHint,
                      controller: _search,
                      onChanged: (_) => setState(() => _openId = null),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (final topic in HelpTopic.values) ...[
                          if (topic != HelpTopic.values.first) const SizedBox(width: 8),
                          Expanded(
                            child: _TopicCard(
                              label: topics[topic]!.$1,
                              icon: topics[topic]!.$2,
                              selected: _topic == topic,
                              // Tapping the chosen topic again clears the filter.
                              onTap: () => setState(() {
                                _topic = _topic == topic ? null : topic;
                                _openId = null;
                              }),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.helpNoResultsTitle,
                            textAlign: TextAlign.center,
                            style: t.body.copyWith(color: c.inkSecondary),
                          ),
                        ),
                      )
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: const BorderRadius.all(SeenRadius.r22),
                          border: Border.all(color: c.border),
                          boxShadow: SeenShadows.card,
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(SeenRadius.r22),
                          child: Column(
                            children: [
                              for (var i = 0; i < shown.length; i++) ...[
                                if (i > 0) Divider(height: 1, color: c.border),
                                _FaqRow(
                                  article: shown[i],
                                  open: _openId == shown[i].id,
                                  onTap: () => setState(() => _openId = _openId == shown[i].id ? null : shown[i].id),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Center(child: SeenTextLink(label: l10n.helpNoResultsContact, onTap: () => _contact(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? SeenBrand.violet05 : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SeenRadius.lg),
          side: BorderSide(color: selected ? c.primary : c.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
            child: Column(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(11))),
                  child: SizedBox(width: 36, height: 36, child: Center(child: SeenSvgIcon(icon, size: 20, color: c.primary))),
                ),
                const SizedBox(height: 6),
                Text(label, style: t.label.copyWith(color: c.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A question that opens to its answer; the chevron turns down while open.
class _FaqRow extends StatelessWidget {
  const _FaqRow({required this.article, required this.open, required this.onTap});

  final HelpArticle article;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(article.question, style: t.body.copyWith(color: c.ink))),
                  const SizedBox(width: 8),
                  RotatedBox(
                    quarterTurns: open ? 1 : 0,
                    child: Icon(SeenIcons.forward(context), size: 18, color: c.inkMuted),
                  ),
                ],
              ),
              if (open) ...[
                const SizedBox(height: 8),
                Text(article.answer, style: t.body.copyWith(color: c.inkSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
