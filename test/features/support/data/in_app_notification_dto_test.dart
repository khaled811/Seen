// The server's notification kinds land on the app's event types; an unknown one stays neutral.

import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/features/support/data/models/in_app_notification_dto.dart';

NotificationEventType _typeOf(String kind) => InAppNotificationDto.parse(
      {'id': '1', 'createdAt': '2026-10-21T10:00:00Z', 'eventType': kind, 'kind': kind},
      AppLanguage('en'),
    ).type;

void main() {
  test('every kind the backend lists maps to an event type', () {
    const kinds = [
      'request_submitted', 'request_under_review', 'request_processing', 'request_completed', 'request_cancelled',
      'request_rejected', 'info_required', 'output_ready', 'topup_requested', 'topup_approved', 'topup_rejected',
      'ticket_update', 'low_balance', 'sla_breach', 'companion_due', 'assigned',
    ];
    for (final k in kinds) {
      expect(_typeOf(k), isNot(NotificationEventType.unknown), reason: k);
    }
    expect(_typeOf('request_rejected'), NotificationEventType.rejected);
    expect(_typeOf('topup_approved'), NotificationEventType.topUp);
  });

  test('a kind the app does not know (including generic) stays unknown', () {
    expect(_typeOf('generic'), NotificationEventType.unknown);
    expect(_typeOf('something_new'), NotificationEventType.unknown);
  });
}
