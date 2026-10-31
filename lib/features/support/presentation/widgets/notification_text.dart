import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/in_app_notification.dart';

/// The words of a notification. The server sends no title or text (only what the
/// notification is about), and its event vocabulary is not published, so the
/// wording follows the structure: a ticket, a request, an amount. It claims
/// nothing about *what happened* that the data does not say.
abstract final class NotificationText {
  static String title(SeenStrings s, InAppNotification n) {
    final subject = n.ticketSubject;
    if (subject != null) return subject;
    final reference = n.referenceCode;
    if (reference != null) return s.notificationOnRequest(reference);
    if (n.amountCents != null) return s.notificationWalletMovement;
    if (n.type == NotificationEventType.slaBreach || n.type == NotificationEventType.ticketUpdate) {
      return s.notificationSupport;
    }
    return s.notificationGeneric;
  }

  /// The muted detail: service, traveler (masked as sent) and amount.
  static String detail(InAppNotification n) {
    final amount = n.amountCents;
    return [
      if (n.serviceName != null) n.serviceName!,
      if (n.travelerLabel != null) n.travelerLabel!,
      if (amount != null) SeenFormat.isolate('${MoneyParser.decimalStringFromCents(amount)}${n.currency == null ? '' : ' ${n.currency}'}'),
    ].join(' · ');
  }
}
