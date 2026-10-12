// Status vocabulary shared by StatusBadge, RequestCard, LedgerRow, ApprovalCard.
//
// A separate, presentation-only vocabulary from this app's domain enums
// (`RequestStatus`, `SupportTicketStatus`, `TravelerApprovalStatus` — see
// `core/constants/enums.dart` / the requests & support features). Kept
// distinct on purpose: `Do NOT introduce breaking changes to existing
// domain entities` — reconciling the two (e.g. mapping `RequestStatus` to
// `SeenStatus` at call sites) is a deliberate follow-up, not part of this
// migration.
import 'package:flutter/widgets.dart';

import '../../theme/seen_colors.dart';
import 'seen_icons.dart';
import 'seen_strings.dart';

enum SeenStatus { review, pending, hold, action, rejected, completed, approved, posted }

extension SeenStatusX on SeenStatus {
  SeenTone get tone => switch (this) {
        SeenStatus.review || SeenStatus.pending || SeenStatus.hold => SeenTone.pending,
        SeenStatus.action || SeenStatus.rejected => SeenTone.danger,
        SeenStatus.completed || SeenStatus.approved || SeenStatus.posted => SeenTone.success,
      };

  IconData get icon => switch (this) {
        SeenStatus.review || SeenStatus.pending => SeenIcons.clock,
        SeenStatus.hold => SeenIcons.lock,
        SeenStatus.action => SeenIcons.alert,
        SeenStatus.rejected => SeenIcons.x,
        SeenStatus.completed || SeenStatus.approved || SeenStatus.posted => SeenIcons.check,
      };

  String label(BuildContext context) {
    final s = SeenStrings.of(context);
    return switch (this) {
      SeenStatus.review => s.review,
      SeenStatus.pending => s.pending,
      SeenStatus.hold => s.hold,
      SeenStatus.action => s.action,
      SeenStatus.rejected => s.rejected,
      SeenStatus.completed => s.completed,
      SeenStatus.approved => s.approved,
      SeenStatus.posted => s.posted,
    };
  }
}
