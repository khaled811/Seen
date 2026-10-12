import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';

abstract final class TicketCategoryLabel {
  static String label(AppLocalizations l10n, TicketCategory category) => switch (category) {
        TicketCategory.general => l10n.ticketCategoryGeneral,
        TicketCategory.financialCorrection => l10n.ticketCategoryFinancialCorrection,
        TicketCategory.unknown => l10n.error,
      };
}
