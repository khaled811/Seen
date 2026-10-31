import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/support/domain/entities/ticket_category_option.dart';
import 'package:seen_booking/features/support/domain/repositories/ticket_categories_repository.dart';
import 'package:seen_booking/features/support/domain/repositories/ticket_rating_repository.dart';
import 'package:seen_booking/features/support/domain/repositories/unread_tickets_repository.dart';

/// A scripted [TicketRatingRepository]; set the answer, read the calls.
class FakeTicketRatingRepository implements TicketRatingRepository {
  Either<Failure, void> result = const Right(null);

  /// When set, `rate` waits for it (to see the "sending" state).
  Completer<void>? hold;

  final rated = <({String ticketId, int rating})>[];

  @override
  Future<Either<Failure, void>> rate(String ticketId, int rating) async {
    rated.add((ticketId: ticketId, rating: rating));
    await hold?.future;
    return result;
  }
}

/// A scripted [TicketCategoriesRepository].
class FakeTicketCategoriesRepository implements TicketCategoriesRepository {
  Either<Failure, List<TicketCategoryOption>> result = const Right([
    TicketCategoryOption(code: 'bookings', name: 'الحجوزات والتذاكر', sortOrder: 1),
    TicketCategoryOption(code: 'payments', name: 'المدفوعات والمحفظة', sortOrder: 2),
    TicketCategoryOption(code: 'account', name: 'الحساب والصلاحيات', sortOrder: 3),
    TicketCategoryOption(code: 'general', name: 'عام', sortOrder: 99),
  ]);

  int calls = 0;

  @override
  Future<Either<Failure, List<TicketCategoryOption>>> list() async {
    calls++;
    return result;
  }
}

/// A scripted [UnreadTicketsRepository].
class FakeUnreadTicketsRepository implements UnreadTicketsRepository {
  Either<Failure, int> result = const Right(0);
  int calls = 0;

  @override
  Future<Either<Failure, int>> count() async {
    calls++;
    return result;
  }
}
