// Ticket thread (Figma SUP-03): the agent's messages on the start side, support's
// on the other, a day separator, messages still being sent or failed (with a
// resend), and a closed ticket that is read-only until it is reopened.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/entities/ticket_message.dart';
import '../bloc/support_bloc.dart';
import '../bloc/support_event.dart';
import '../bloc/support_state.dart';
import '../bloc/ticket_actions_cubit.dart';

/// Chat-style ticket thread, reactive to the same [SupportBloc] the list
/// screen owns — a reply posted here shows up immediately, and re-opening
/// the ticket from the list reflects any change without a separate fetch.
class TicketDetailScreen extends StatelessWidget {
  const TicketDetailScreen({super.key, required this.ticketId, this.createActionsCubit});

  final String ticketId;

  /// Test seam for the mark-read / reopen cubit; defaults to the DI container.
  final TicketActionsCubit Function()? createActionsCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createActionsCubit ?? InjectionContainer.instance.createTicketActionsCubit)(),
      child: _ThreadView(ticketId: ticketId),
    );
  }
}

class _ThreadView extends StatefulWidget {
  const _ThreadView({required this.ticketId});

  final String ticketId;

  @override
  State<_ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<_ThreadView> {
  // Owned here, disposed in dispose().
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Opening the thread reads it: clear the marker here and on the server.
    final bloc = context.read<SupportBloc>();
    final state = bloc.state;
    if (state is SupportLoaded && (state.ticketById(widget.ticketId)?.hasUnreadReply ?? false)) {
      bloc.add(SupportTicketMarkedRead(widget.ticketId));
      context.read<TicketActionsCubit>().markRead(widget.ticketId);
    }
  }

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

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<SupportBloc, SupportState>(
          listenWhen: (previous, current) => current is SupportLoaded && current.replyStatus == ReplyStatus.failure,
          listener: (context, state) => _toast((state as SupportLoaded).replyError ?? l10n.error),
        ),
        BlocListener<TicketActionsCubit, TicketActionsState>(
          listenWhen: (previous, current) => previous.seq != current.seq,
          listener: (context, state) {
            if (state.status == TicketActionStatus.reopened && state.ticket != null) {
              context.read<SupportBloc>().add(SupportTicketReplaced(state.ticket!));
            } else if (state.status == TicketActionStatus.failed) {
              _toast(state.message ?? l10n.error);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: c.card,
        body: SeenScreenBackground(
          child: SafeArea(
            bottom: false,
            child: BlocBuilder<SupportBloc, SupportState>(
              builder: (context, state) {
                final ticket = state is SupportLoaded ? state.ticketById(widget.ticketId) : null;
                if (ticket == null) {
                  return Column(
                    children: [
                      SeenScreenHeader(title: l10n.ticketDetailTitle),
                      const Expanded(child: Center(child: SeenLoader())),
                    ],
                  );
                }
                final outbox = (state as SupportLoaded).outboxFor(widget.ticketId);
                return Column(
                  children: [
                    SeenScreenHeader(title: ticket.referenceId, subtitle: ticket.subject),
                    Expanded(child: _Thread(ticket: ticket, outbox: outbox)),
                    if (ticket.isClosed)
                      _ClosedBar(ticketId: ticket.id)
                    else
                      _Composer(
                        controller: _messageController,
                        onSend: () => _send(context),
                        onAttach: () => _toast(l10n.ticketAttachComingSoon),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  const _Thread({required this.ticket, required this.outbox});

  final SupportTicket ticket;
  final List<OutboxMessage> outbox;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final now = DateTime.now();

    String dayLabel(DateTime d) {
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(d.year, d.month, d.day);
      final diff = today.difference(day).inDays;
      if (diff == 0) return l10n.ticketToday;
      if (diff == 1) return l10n.ticketYesterday;
      return s.dayMonth(d);
    }

    // Oldest first, then reversed for the bottom-anchored list.
    final entries = <({DateTime at, Widget bubble})>[
      for (final m in ticket.messages) (at: m.sentAt, bubble: _Bubble.sent(message: m)),
      for (final m in outbox) (at: m.sentAt, bubble: _Bubble.pending(message: m)),
    ];
    final children = <Widget>[];
    DateTime? lastDay;
    for (final entry in entries) {
      final day = DateTime(entry.at.year, entry.at.month, entry.at.day);
      if (lastDay != day) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Center(child: Text(dayLabel(entry.at), style: t.caption.copyWith(color: c.inkMuted))),
          ),
        );
        lastDay = day;
      }
      children.add(entry.bubble);
    }
    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(20, SeenSpace.s1, 20, SeenSpace.s3),
      children: children.reversed.toList(),
    );
  }
}

/// One message: the agent's (white, start side), support's (violet, end side), or
/// the agent's still being sent / failed.
class _Bubble extends StatelessWidget {
  const _Bubble.sent({required TicketMessage message})
      : sent = message,
        pending = null;

  const _Bubble.pending({required OutboxMessage message})
      : sent = null,
        pending = message;

  final TicketMessage? sent;
  final OutboxMessage? pending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final fromSupport = sent?.isSupportReply ?? false;
    final text = sent?.body ?? pending!.body;
    final at = sent?.sentAt ?? pending!.sentAt;
    final failed = pending?.status == OutboxStatus.failed;
    final time = SeenFormat.time(at);
    final meta = switch ((sent, pending)) {
      (final m?, _) when fromSupport => '$time · ${m.authorName}',
      (_, final p?) => p.status == OutboxStatus.failed
          ? '$time · ${l10n.ticketSendFailed}'
          : '$time · ${l10n.ticketSending}',
      _ => time,
    };
    final metaColor = failed ? SeenColors.of(context).dangerFg : c.inkMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: fromSupport ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fromSupport ? SeenBrand.violet10 : c.card,
                  borderRadius: const BorderRadius.all(SeenRadius.r18),
                  border: fromSupport ? null : Border.all(color: c.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(text, style: t.body.copyWith(color: c.ink)),
                      const SizedBox(height: 4),
                      Text(meta, textDirection: null, style: t.caption.copyWith(color: metaColor)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (failed)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SeenTextLink(
                label: l10n.ticketResend,
                onTap: () => context.read<SupportBloc>().add(SupportOutboxRetryRequested(pending!.localId)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.onAttach});

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.card, boxShadow: SeenShadows.stickyBar),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: SeenBrand.violet05,
                    borderRadius: BorderRadius.all(SeenRadius.full),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Semantics(
                        button: true,
                        label: l10n.ticketAttachOptional,
                        excludeSemantics: true,
                        child: InkResponse(
                          onTap: onAttach,
                          radius: 20,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: SeenSvgIcon(SeenVectors.authUpload, size: 18, color: c.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          style: t.body.copyWith(color: c.ink),
                          decoration: InputDecoration(
                            hintText: l10n.ticketReplyHint,
                            hintStyle: t.body.copyWith(color: c.inkMuted),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: l10n.ticketSendMessageTooltip,
                excludeSemantics: true,
                child: DecoratedBox(
                  decoration: const BoxDecoration(gradient: SeenBrand.gradientCta, shape: BoxShape.circle),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: onSend,
                      customBorder: const CircleBorder(),
                      child: SizedBox(width: 44, height: 44, child: Icon(SeenIcons.send, size: 20, color: c.onPrimary)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A closed ticket is read-only: say so, offer to reopen it.
class _ClosedBar extends StatelessWidget {
  const _ClosedBar({required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.card, boxShadow: SeenShadows.stickyBar),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: SeenBrand.violet05, borderRadius: BorderRadius.all(SeenRadius.r12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.ticketClosedNote, style: t.caption.copyWith(color: c.inkMuted))),
                  BlocBuilder<TicketActionsCubit, TicketActionsState>(
                    builder: (context, state) {
                      final working = state.status == TicketActionStatus.working;
                      return SeenTextLink(
                        label: l10n.ticketReopen,
                        onTap: working ? null : () => context.read<TicketActionsCubit>().reopen(ticketId),
                      );
                    },
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
