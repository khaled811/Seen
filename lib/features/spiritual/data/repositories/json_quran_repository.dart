import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/quran_data.dart';
import '../../domain/repositories/quran_repository.dart';
import '../models/quran_parser.dart';

/// Loads the bundled Quran once. The 1.7 MB JSON is decoded on a background
/// isolate so opening the mushaf never janks the UI thread.
class JsonQuranRepository implements QuranRepository {
  JsonQuranRepository({
    AssetBundle? bundle,
    this.assetPath = 'assets/data/quran.json',
    this.useIsolate = true,
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;
  final bool useIsolate;

  QuranData? _cache;
  Future<Either<Failure, QuranData>>? _inflight;

  @override
  Future<Either<Failure, QuranData>> load() {
    final cached = _cache;
    if (cached != null) return Future.value(Right(cached));
    // Concurrent callers share one load instead of parsing twice.
    return _inflight ??= _read().whenComplete(() => _inflight = null);
  }

  Future<Either<Failure, QuranData>> _read() async {
    try {
      final source = await _bundle.loadString(assetPath);
      final data = useIsolate
          ? await compute(parseQuranJson, source)
          : parseQuranJson(source);
      _cache = data;
      return Right(data);
    } catch (e) {
      return Left(CacheFailure('Could not load the Quran: $e'));
    }
  }
}
