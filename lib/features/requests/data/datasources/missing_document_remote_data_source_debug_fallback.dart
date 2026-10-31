import '../../../../core/config/debug_fallbacks.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/missing_document.dart';
import 'missing_document_remote_data_source.dart';

/// DEBUG ONLY (opt-in with `USE_DEBUG_FALLBACKS`): when a real call fails in a
/// debug build, answers with canned results so the upload screens can be tried
/// without a server. `kDebugMode` is a compile-time constant, so release builds
/// drop the branches.
///
/// Demo rules: a file name containing `fail` fails once with a network error
/// (retry succeeds), `late` is refused as no longer accepted, anything else
/// uploads with simulated progress.
class DebugFallbackMissingDocumentRemoteDataSource implements MissingDocumentRemoteDataSource {
  DebugFallbackMissingDocumentRemoteDataSource(this._real);

  final MissingDocumentRemoteDataSource _real;
  bool _failedOnce = false;

  @override
  Future<Either<Failure, MissingDocumentRequest>> getMissingDocument(String requestId) async {
    final result = await _real.getMissingDocument(requestId);
    if (!(debugFallbacksEnabled && result.isLeft())) return result;
    return Right(MissingDocumentRequest(
      requestId: requestId,
      referenceId: 'SB-20476',
      reason: 'الصورة الحالية غير مقروءة، والصفحة الأولى مقصوصة. صوّر صفحة البيانات كاملة في إضاءة جيدة.',
      deadline: DateTime.now().add(const Duration(hours: 46, minutes: 12, seconds: 8)),
      targets: const [
        UploadTarget(
          travelerId: 'debug-traveler',
          requirementId: 'debug-requirement',
          requirementLabel: 'صورة جواز واضحة',
          travelerLabel: 'رقية أحمد الحميري',
        ),
      ],
    ));
  }

  @override
  Future<Either<Failure, void>> upload({
    required UploadTarget target,
    required PickedDocument document,
    void Function(double fraction)? onProgress,
  }) async {
    final result = await _real.upload(target: target, document: document, onProgress: onProgress);
    if (!(debugFallbacksEnabled && result.isLeft())) return result;
    final name = document.fileName.toLowerCase();
    for (final step in [0.15, 0.4, 0.68, 0.9]) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      onProgress?.call(step);
    }
    if (name.contains('late')) {
      return const Left(ServerFailure('Not accepted', code: DocumentIssue.notAllowedCode));
    }
    if (name.contains('fail') && !_failedOnce) {
      _failedOnce = true;
      return const Left(NetworkFailure('offline'));
    }
    onProgress?.call(1);
    return const Right(null);
  }
}
