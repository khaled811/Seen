import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';

abstract final class TicketCategoryLabel {
  static String label(AppLocalizations l10n, TicketCategory category) => switch (category) {
        TicketCategory.general => l10n.ticketCategoryGeneral,
        TicketCategory.financialCorrection => l10n.ticketCategoryFinancialCorrection,
        // A category the app does not know (a live chat, a custom one) is shown as general.
        TicketCategory.unknown => l10n.ticketCategoryGeneral,
      };
}
