// Support tickets list (Figma SUP-01): open / closed tabs, a card per ticket
// with its status, an unread-reply marker and the time of the last activity;
// loading skeletons, an error with retry and the empty states.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/support_ticket.dart';
import '../bloc/support_bloc.dart';
import '../bloc/support_event.dart';
import '../bloc/support_state.dart';
import '../widgets/ticket_category_label.dart';
import 'create_ticket_screen.dart';
import 'ticket_detail_screen.dart';

const _gutter = 14.0;

/// Entry point for the Support Tickets feature.
class SupportTicketsScreen extends StatelessWidget {
  const SupportTicketsScreen({super.key, this.createBloc});

  /// Test seam; defaults to the DI container.
  final SupportBloc Function()? createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createBloc ?? InjectionContainer.instance.createSupportBloc)()..add(const SupportTicketsLoadRequested()),
      child: const _TicketsView(),
    );
  }
}

class _TicketsView extends StatefulWidget {
  const _TicketsView();

  @override
  State<_TicketsView> createState() => _TicketsViewState();
}

class _TicketsViewState extends State<_TicketsView> {
  bool _closedTab = false;

  void _openTicket(BuildContext context, String ticketId) {
    final bloc = context.read<SupportBloc>();
    // A route pushed via Navigator isn't a descendant of this screen's
    // BlocProvider (it attaches to the Navigator's Overlay), so the same
    // Bloc instance must be forwarded explicitly.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(value: bloc, child: TicketDetailScreen(ticketId: ticketId)),
      ),
    );
  }

  void _openCreateTicket(BuildContext context) {
    final bloc = context.read<SupportBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(value: bloc, child: const CreateTicketScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return BlocListener<SupportBloc, SupportState>(
      listenWhen: (previous, current) => current is SupportLoaded && current.createdTicketId != null,
      listener: (context, state) {
        final ticketId = (state as SupportLoaded).createdTicketId!;
        context.read<SupportBloc>().add(const SupportTicketCreateAcknowledged());
        _openTicket(context, ticketId);
      },
      child: Scaffold(
        backgroundColor: c.card,
        body: SeenScreenBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                SeenScreenHeader(
                  title: l10n.supportTicketsTitle,
                  trailing: Semantics(
                    button: true,
                    label: l10n.createTicketAction,
                    excludeSemantics: true,
                    child: Material(
                      color: SeenBrand.violet10,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => _openCreateTicket(context),
                        customBorder: const CircleBorder(),
                        child: SizedBox(width: 44, height: 44, child: Icon(SeenIcons.plus, size: 22, color: c.primary)),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: BlocBuilder<SupportBloc, SupportState>(
                    builder: (context, state) => switch (state) {
                      SupportInitial() || SupportLoading() => const _Skeleton(),
                      SupportFailure(:final message) => _ErrorView(message: message),
                      SupportLoaded(:final tickets) => _Loaded(
                          tickets: tickets,
                          closedTab: _closedTab,
                          onTab: (closed) => setState(() => _closedTab = closed),
                          onOpen: (id) => _openTicket(context, id),
                          onCreate: () => _openCreateTicket(context),
                        ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.tickets,
    required this.closedTab,
    required this.onTab,
    required this.onOpen,
    required this.onCreate,
  });

  final List<SupportTicket> tickets;
  final bool closedTab;
  final ValueChanged<bool> onTab;
  final ValueChanged<String> onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    // Newest activity first. Resolved and closed tickets are "closed".
    final sorted = [...tickets]..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    final open = [for (final t in sorted) if (t.isLive) t];
    final closed = [for (final t in sorted) if (!t.isLive) t];
    final shown = closedTab ? closed : open;
    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<SupportBloc>()..add(const SupportTicketsLoadRequested());
        await bloc.stream.firstWhere((x) => x is! SupportLoading);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s1, _gutter, SeenSpace.s6),
        children: [
          _Tabs(
            openLabel: open.isEmpty ? l10n.ticketStatusOpen : '${l10n.ticketStatusOpen} · ${s.numeral(open.length)}',
            closedLabel: l10n.ticketStatusClosed,
            closedSelected: closedTab,
            onSelected: onTab,
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: SeenEmptyState(
                iconAsset: SeenVectors.accountSupport,
                title: closedTab ? l10n.ticketsEmptyClosed : l10n.ticketsEmptyOpen,
                message: closedTab ? '' : l10n.ticketsEmptyMessage,
                actionLabel: closedTab ? null : l10n.createTicketAction,
                onAction: closedTab ? null : onCreate,
              ),
            )
          else
            for (final ticket in shown) ...[
              _TicketCard(ticket: ticket, onTap: () => onOpen(ticket.id)),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

/// Open / closed: a soft track with the selected tab raised in white.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.openLabel,
    required this.closedLabel,
    required this.closedSelected,
    required this.onSelected,
  });

  final String openLabel;
  final String closedLabel;
  final bool closedSelected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    Widget tab(String label, bool selected, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            child: Material(
              color: selected ? c.card : Colors.transparent,
              elevation: 0,
              borderRadius: const BorderRadius.all(SeenRadius.r12),
              child: InkWell(
                onTap: onTap,
                borderRadius: const BorderRadius.all(SeenRadius.r12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(SeenRadius.r12),
                    boxShadow: selected ? SeenShadows.card : null,
                  ),
                  child: SizedBox(
                    height: 36,
                    child: Center(
                      child: Text(label, style: t.label.copyWith(color: selected ? c.ink : c.inkSecondary)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return DecoratedBox(
      decoration: const BoxDecoration(color: SeenBrand.violet05, borderRadius: BorderRadius.all(SeenRadius.r14)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            tab(openLabel, !closedSelected, () => onSelected(false)),
            const SizedBox(width: 4),
            tab(closedLabel, closedSelected, () => onSelected(true)),
          ],
        ),
      ),
    );
  }
}

/// The ticket's chip: closed and resolved say so; a live ticket whose newest
/// message is support's is "waiting for you"; otherwise in progress / open.
(SeenRequestStatus, String) ticketChip(AppLocalizations l10n, SupportTicket ticket) {
  if (ticket.status == SupportTicketStatus.closed) return (SeenRequestStatus.cancelled, l10n.ticketStatusClosed);
  if (ticket.status == SupportTicketStatus.resolved) return (SeenRequestStatus.completed, l10n.ticketStatusResolved);
  if (ticket.awaitingAgent) return (SeenRequestStatus.actionRequired, l10n.ticketAwaitingAction);
  if (ticket.status == SupportTicketStatus.inProgress) return (SeenRequestStatus.processing, l10n.ticketStatusInProgress);
  return (SeenRequestStatus.submitted, l10n.ticketStatusOpen);
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final (status, label) = ticketChip(l10n, ticket);
    final unread = ticket.hasUnreadReply;
    final meta = '${ticket.referenceId} · ${TicketCategoryLabel.label(l10n, ticket.category)}';
    final time = s.timeAgo(ticket.lastActivityAt);
    return Semantics(
      button: true,
      container: true,
      label: '${ticket.subject} $label $meta $time${unread ? ' ${l10n.ticketUnreadReplyLabel}' : ''}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(boxShadow: SeenShadows.card, borderRadius: BorderRadius.all(SeenRadius.r22)),
        child: Material(
          color: c.card,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(SeenRadius.r22),
            side: BorderSide(color: c.border),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.r22)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (unread) ...[
                        const DecoratedBox(
                          decoration: BoxDecoration(color: SeenBrand.violet, shape: BoxShape.circle),
                          child: SizedBox(width: 8, height: 8),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: Text(ticket.subject, style: t.label.copyWith(color: c.ink))),
                      const SizedBox(width: SeenSpace.s2),
                      SeenStatusChip(status: status, label: label),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${SeenFormat.isolate(ticket.referenceId)} · ${TicketCategoryLabel.label(l10n, ticket.category)}',
                          style: t.caption.copyWith(color: c.inkMuted),
                        ),
                      ),
                      Text(time, style: t.caption.copyWith(color: unread ? c.primary : c.inkMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s3, _gutter, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: SeenInlineBanner(
          tone: SeenBannerTone.error,
          message: message,
          actionLabel: l10n.retry,
          onAction: () => context.read<SupportBloc>().add(const SupportTicketsLoadRequested()),
        ),
      ),
    );
  }
}

/// Loading: two ticket-shaped blocks.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.loading,
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s1, _gutter, SeenSpace.s6),
          children: [
            for (var i = 0; i < 3; i++) ...[
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Color(0xFFEFEBF8), Color(0xFFF7F5FC)],
                  ),
                  borderRadius: BorderRadius.all(SeenRadius.r22),
                ),
                child: SizedBox(height: 84),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
