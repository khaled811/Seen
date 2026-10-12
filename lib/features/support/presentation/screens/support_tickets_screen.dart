import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/loader.dart';
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
import '../widgets/ticket_status_seen_mapping.dart';
import 'create_ticket_screen.dart';
import 'ticket_detail_screen.dart';

/// Entry point for the Support Tickets feature.
class SupportTicketsScreen extends StatelessWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createSupportBloc()
        ..add(const SupportTicketsLoadRequested()),
      child: const _TicketsView(),
    );
  }
}

class _TicketsView extends StatelessWidget {
  const _TicketsView();

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
    return BlocListener<SupportBloc, SupportState>(
      listenWhen: (previous, current) => current is SupportLoaded && current.createdTicketId != null,
      listener: (context, state) {
        final ticketId = (state as SupportLoaded).createdTicketId!;
        context.read<SupportBloc>().add(const SupportTicketCreateAcknowledged());
        _openTicket(context, ticketId);
      },
      child: Scaffold(
        appBar: SeenTopBar.inner(
          title: l10n.supportTicketsTitle,
          trailing: SeenIconButton(
            icon: SeenIcons.plus,
            semanticLabel: l10n.createTicketAction,
            onPressed: () => _openCreateTicket(context),
          ),
        ),
        body: BlocBuilder<SupportBloc, SupportState>(
          builder: (context, state) {
            return switch (state) {
              SupportInitial() || SupportLoading() => const Center(child: SeenLoader()),
              SupportFailure(:final message) => _ErrorView(message: message),
              SupportLoaded(:final tickets) => tickets.isEmpty
                  ? Center(child: Text(l10n.ticketsEmptyMessage))
                  : ListView.builder(
                      padding: const EdgeInsets.all(SeenSpace.s4),
                      itemCount: tickets.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: SeenSpace.s3),
                        child: _TicketCard(
                          ticket: tickets[index],
                          onTap: () => _openTicket(context, tickets[index].id),
                        ),
                      ),
                    ),
            };
          },
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: SeenSpace.s3),
          SeenButton(
            label: l10n.retry,
            onPressed: () => context.read<SupportBloc>().add(const SupportTicketsLoadRequested()),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(SeenRadius.md),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.md)),
        child: Padding(
          padding: const EdgeInsets.all(SeenSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(ticket.subject, style: text.titleMedium)),
                const SizedBox(width: SeenSpace.s2),
                SeenStatusBadge(status: ticket.status.toSeenStatus),
              ]),
              const SizedBox(height: SeenSpace.s1),
              Text(ticket.referenceId, textDirection: TextDirection.ltr, style: SeenType.of(context).refMono),
              const SizedBox(height: SeenSpace.s1),
              Wrap(spacing: SeenSpace.s3, runSpacing: 2, children: [
                Text(TicketCategoryLabel.label(l10n, ticket.category), style: text.labelSmall),
                if (ticket.isRequestRelated)
                  Text(l10n.ticketLinkedRequestLabel(ticket.requestId!), style: text.labelSmall),
                Text(SeenFormat.date(ticket.createdAt),
                    textDirection: TextDirection.ltr, style: text.labelSmall!.copyWith(fontFeatures: SeenFonts.tabular)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
