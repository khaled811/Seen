import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/missing_document.dart';
import '../models/missing_document_dto.dart';
import 'missing_document_remote_data_source.dart';

/// DEBUG ONLY: when a real call fails in a debug build, answers with canned
/// results so the upload screens can be tried before the backend exists.
/// `kDebugMode` is a compile-time constant, so release builds drop the branches.
///
/// Demo rules: a file name containing `fail` fails once with a network error
/// (retry succeeds), `late` is rejected as past the deadline, anything else
/// uploads with simulated progress.
class DebugFallbackMissingDocumentRemoteDataSource implements MissingDocumentRemoteDataSource {
  DebugFallbackMissingDocumentRemoteDataSource(this._real);

  final MissingDocumentRemoteDataSource _real;
  bool _failedOnce = false;

  @override
  Future<Either<Failure, MissingDocumentDto>> getMissingDocument(String requestId) async {
    final result = await _real.getMissingDocument(requestId);
    if (!(kDebugMode && result.isLeft())) return result;
    return Right(MissingDocumentDto(
      requestId: requestId,
      referenceId: 'SB-20476',
      documentTitle: 'صورة جواز واضحة',
      travelerName: 'رقية أحمد الحميري',
      reason: 'الصورة الحالية غير مقروءة، والصفحة الأولى مقصوصة. صوّر صفحة البيانات كاملة في إضاءة جيدة.',
      deadline: DateTime.now().add(const Duration(hours: 46, minutes: 12, seconds: 8)),
    ));
  }

  @override
  Future<Either<Failure, void>> upload({
    required String requestId,
    required PickedDocument document,
    void Function(double fraction)? onProgress,
  }) async {
    final result = await _real.upload(requestId: requestId, document: document, onProgress: onProgress);
    if (!(kDebugMode && result.isLeft())) return result;
    final name = document.fileName.toLowerCase();
    for (final step in [0.15, 0.4, 0.68, 0.9]) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      onProgress?.call(step);
    }
    if (name.contains('late')) {
      return const Left(ServerFailure('Deadline passed', code: DocumentIssue.deadlinePassedCode));
    }
    if (name.contains('fail') && !_failedOnce) {
      _failedOnce = true;
      return const Left(NetworkFailure('offline'));
    }
    onProgress?.call(1);
    return const Right(null);
  }
}
