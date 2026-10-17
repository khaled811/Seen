import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/booking_draft.dart';

abstract interface class BookingDraftRepository {
  /// The current agent's drafts, newest edit first; expired ones are deleted.
  Future<Either<Failure, List<BookingDraft>>> getDrafts();

  /// Saves (insert or overwrite by id). A new draft is refused with
  /// [SaveDraftResult.limitReached] once [BookingDraft.maxCount] exist.
  Future<Either<Failure, SaveDraftResult>> saveDraft(BookingDraft draft);

  Future<Either<Failure, void>> deleteDraft(String id);
}
