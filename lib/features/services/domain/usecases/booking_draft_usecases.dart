import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/booking_draft.dart';
import '../repositories/booking_draft_repository.dart';

class GetBookingDraftsUseCase {
  const GetBookingDraftsUseCase(this._repository);
  final BookingDraftRepository _repository;

  Future<Either<Failure, List<BookingDraft>>> call() => _repository.getDrafts();
}

class SaveBookingDraftUseCase {
  const SaveBookingDraftUseCase(this._repository);
  final BookingDraftRepository _repository;

  Future<Either<Failure, SaveDraftResult>> call(BookingDraft draft) => _repository.saveDraft(draft);
}

class DeleteBookingDraftUseCase {
  const DeleteBookingDraftUseCase(this._repository);
  final BookingDraftRepository _repository;

  Future<Either<Failure, void>> call(String id) => _repository.deleteDraft(id);
}
