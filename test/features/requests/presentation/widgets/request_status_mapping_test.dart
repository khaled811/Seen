import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/presentation/widgets/status.dart';
import 'package:seen_booking/core/theme/seen_colors.dart';
import 'package:seen_booking/features/requests/presentation/widgets/request_status_seen_mapping.dart';

void main() {
  final now = DateTime(2026, 10, 13, 12);

  group('toSeenRequestStatus', () {
    test('plain backend statuses map to their Figma chip', () {
      expect(RequestStatus.draft.toSeenRequestStatus(), SeenRequestStatus.newRequest);
      expect(RequestStatus.unknown.toSeenRequestStatus(), SeenRequestStatus.newRequest);
      expect(RequestStatus.submitted.toSeenRequestStatus(), SeenRequestStatus.submitted);
      expect(RequestStatus.pendingAgentApproval.toSeenRequestStatus(), SeenRequestStatus.submitted);
      expect(RequestStatus.pendingManagementApproval.toSeenRequestStatus(), SeenRequestStatus.submitted);
      expect(RequestStatus.underReview.toSeenRequestStatus(), SeenRequestStatus.underReview);
      expect(RequestStatus.processing.toSeenRequestStatus(), SeenRequestStatus.processing);
      expect(RequestStatus.completed.toSeenRequestStatus(), SeenRequestStatus.completed);
      expect(RequestStatus.rejected.toSeenRequestStatus(), SeenRequestStatus.rejected);
      expect(RequestStatus.cancelled.toSeenRequestStatus(), SeenRequestStatus.cancelled);
    });

    test('info required is evaluated against the 72h SLA deadline', () {
      SeenRequestStatus at(Duration left) =>
          RequestStatus.infoRequired.toSeenRequestStatus(slaDeadline: now.add(left), now: now);

      expect(at(const Duration(hours: 52)), SeenRequestStatus.actionRequired);
      expect(at(const Duration(hours: 24)), SeenRequestStatus.actionRequired);
      expect(at(const Duration(hours: 23, minutes: 59)), SeenRequestStatus.deadlineUnder24h);
      expect(at(const Duration(minutes: 1)), SeenRequestStatus.deadlineUnder24h);
      expect(at(Duration.zero), SeenRequestStatus.expired);
      expect(at(const Duration(hours: -3)), SeenRequestStatus.expired);
      expect(RequestStatus.infoRequired.toSeenRequestStatus(now: now), SeenRequestStatus.actionRequired);
    });

    test('withAuthority and confirmed are never produced from a backend status', () {
      final produced = {for (final s in RequestStatus.values) s.toSeenRequestStatus(now: now)};
      expect(produced, isNot(contains(SeenRequestStatus.withAuthority)));
      expect(produced, isNot(contains(SeenRequestStatus.confirmed)));
    });
  });

  group('progress', () {
    test('steps follow the 5-step journey', () {
      expect(RequestStatus.submitted.progress.step, 1);
      expect(RequestStatus.underReview.progress.step, 2);
      expect(RequestStatus.processing.progress.step, 3);
      expect(RequestStatus.completed.progress.step, 5);
      expect(RequestStatus.completed.progress.total, 5);
    });

    test('action required is the review step, blocked on the agency', () {
      final p = RequestStatus.infoRequired.progress;
      expect(p.step, 2);
      expect(p.waiting, isTrue);
    });

    test('rejected, cancelled and unknown hide the progress row', () {
      for (final s in [RequestStatus.rejected, RequestStatus.cancelled, RequestStatus.unknown]) {
        expect(s.progress.isVisible, isFalse, reason: '$s');
      }
    });
  });

  group('seenCountdownState', () {
    test('warm / urgent / expired / none', () {
      expect(seenCountdownState(now.add(const Duration(hours: 50)), now: now), SeenCountdownState.warm);
      expect(seenCountdownState(now.add(const Duration(hours: 5)), now: now), SeenCountdownState.urgent);
      expect(seenCountdownState(now.subtract(const Duration(minutes: 1)), now: now), SeenCountdownState.expired);
      expect(seenCountdownState(null, now: now), isNull);
    });
  });
}
