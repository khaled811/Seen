import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/entities/ticket_message.dart';
import '../bloc/support_bloc.dart';
import '../bloc/support_event.dart';
import '../bloc/support_state.dart';
import '../widgets/ticket_status_seen_mapping.dart';

/// Chat-style ticket thread, reactive to the same [SupportBloc] the list
/// screen owns — a reply posted here shows up immediately, and re-opening
/// the ticket from the list reflects any change without a separate fetch.
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _send(BuildContext context) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    context.read<SupportBloc>().add(SupportTicketReplySubmitted(ticketId: widget.ticketId, message: text));
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return BlocListener<SupportBloc, SupportState>(
      listenWhen: (previous, current) =>
          current is SupportLoaded && current.replyStatus == ReplyStatus.failure,
      listener: (context, state) {
        final message = (state as SupportLoaded).replyError ?? l10n.error;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      child: Scaffold(
        appBar: SeenTopBar.inner(title: l10n.ticketDetailTitle),
        body: BlocBuilder<SupportBloc, SupportState>(
          builder: (context, state) {
            final ticket = state is SupportLoaded ? state.ticketById(widget.ticketId) : null;
            if (ticket == null) {
              return const Center(child: SeenLoader());
            }
            final isReplying = state is SupportLoaded &&
                state.replyStatus == ReplyStatus.submitting &&
                state.replyingTicketId == widget.ticketId;
            return Column(
              children: [
                _TicketHeader(ticket: ticket),
                Divider(height: 1, color: c.border),
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(SeenSpace.s4),
                    itemCount: ticket.messages.length,
                    itemBuilder: (context, index) =>
                        _MessageBubble(message: ticket.messages[ticket.messages.length - 1 - index]),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(color: c.card, boxShadow: c.sheetShadow),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.all(SeenSpace.s3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: l10n.ticketReplyHint,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: SeenSpace.s2),
                        isReplying
                            ? const Padding(
                                padding: EdgeInsets.all(SeenSpace.s2),
                                child: SeenLoader(size: 20),
                              )
                            : SeenIconButton(
                                icon: SeenIcons.send,
                                semanticLabel: l10n.ticketSendMessageTooltip,
                                color: c.primaryInk,
                                onPressed: () => _send(context),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TicketHeader extends StatelessWidget {
  const _TicketHeader({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(SeenSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket.subject, style: text.titleMedium),
                Text(ticket.referenceId, textDirection: TextDirection.ltr, style: text.labelSmall),
                if (ticket.isRequestRelated)
                  Text(l10n.ticketLinkedRequestLabel(ticket.requestId!), style: text.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: SeenSpace.s2),
          SeenStatusBadge(status: ticket.status.toSeenStatus),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    final isSupport = message.isSupportReply;
    return Align(
      alignment: isSupport ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: SeenSpace.s1),
        padding: const EdgeInsets.all(SeenSpace.s3),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isSupport ? c.surfaceSunken : c.accentSoft,
          borderRadius: const BorderRadius.all(SeenRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.authorName, style: text.labelSmall!.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: SeenSpace.s1),
            Text(message.body, style: text.bodyMedium),
            const SizedBox(height: SeenSpace.s1),
            Text(
              SeenFormat.isolate('${SeenFormat.date(message.sentAt)} ${SeenFormat.time(message.sentAt)}'),
              style: text.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
