import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/booking_draft.dart';
import '../../domain/repositories/booking_draft_repository.dart';
import '../datasources/booking_draft_local_data_source.dart';

class BookingDraftRepositoryImpl implements BookingDraftRepository {
  BookingDraftRepositoryImpl({required BookingDraftLocalDataSource local, DateTime Function() clock = DateTime.now})
      : _local = local,
        _clock = clock;

  final BookingDraftLocalDataSource _local;
  final DateTime Function() _clock;

  @override
  Future<Either<Failure, List<BookingDraft>>> getDrafts() async {
    try {
      final now = _clock();
      final all = await _local.read();
      final alive = all.where((d) => !d.isExpired(now)).toList();
      // Expired drafts are removed for good the first time they are noticed.
      if (alive.length != all.length) await _local.write(alive);
      alive.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return Right(alive);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SaveDraftResult>> saveDraft(BookingDraft draft) async {
    try {
      final now = _clock();
      final all = (await _local.read()).where((d) => !d.isExpired(now)).toList();
      final index = all.indexWhere((d) => d.id == draft.id);
      if (index < 0 && all.length >= BookingDraft.maxCount) return const Right(SaveDraftResult.limitReached);
      if (index < 0) {
        all.add(draft);
      } else {
        all[index] = draft;
      }
      await _local.write(all);
      return const Right(SaveDraftResult.saved);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteDraft(String id) async {
    try {
      await _local.write((await _local.read()).where((d) => d.id != id).toList());
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
