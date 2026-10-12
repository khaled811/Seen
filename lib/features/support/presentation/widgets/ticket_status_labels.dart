import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/entities/support_ticket.dart';

abstract final class TicketStatusLabels {
  static String of(AppLocalizations l10n, SupportTicketStatus status) => switch (status) {
        SupportTicketStatus.open => l10n.ticketStatusOpen,
        SupportTicketStatus.inProgress => l10n.ticketStatusInProgress,
        SupportTicketStatus.resolved => l10n.ticketStatusResolved,
        SupportTicketStatus.closed => l10n.ticketStatusClosed,
        SupportTicketStatus.unknown => l10n.error,
      };
}
