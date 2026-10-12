import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/dua.dart';
import '../../domain/repositories/dua_repository.dart';

/// Loads duas from `assets/data/duas.json` (docs/05-content.md). Entries not
/// yet signed off by a scholar (`reviewed: false`) are dropped in release
/// builds.
class JsonDuaRepository implements DuaRepository {
  JsonDuaRepository({
    AssetBundle? bundle,
    this.assetPath = 'assets/data/duas.json',
    bool? includeUnreviewed,
  })  : _bundle = bundle ?? rootBundle,
        includeUnreviewed = includeUnreviewed ?? !kReleaseMode;

  final AssetBundle _bundle;
  final String assetPath;
  final bool includeUnreviewed;

  List<Dua>? _cache;

  @override
  Future<Either<Failure, List<Dua>>> getDuas({DuaCategory? category}) async {
    try {
      final all = _cache ??= _parse(await _bundle.loadString(assetPath));
      final visible = all.where(
        (d) =>
            (includeUnreviewed || d.reviewed) &&
            (category == null || d.category == category),
      );
      return Right(visible.toList(growable: false));
    } catch (e) {
      return Left(CacheFailure('Could not load duas: $e'));
    }
  }

  static List<Dua> _parse(String source) {
    final list = jsonDecode(source);
    if (list is! List) throw const FormatException('duas.json is not a list');
    return [
      for (final e in list.cast<Map<String, Object?>>())
        Dua(
          id: e['id']! as String,
          category: DuaCategory.values.firstWhere(
            (c) => c.name == e['category'],
          ),
          title: e['title']! as String,
          text: e['text']! as String,
          isQuranic: e['isQuranic'] as bool? ?? false,
          source: e['source']! as String,
          note: e['note'] as String?,
          repeat: e['repeat'] as int? ?? 1,
          audioAsset: e['audio'] as String?,
          durationSec: e['durationSec'] as int?,
          reviewed: e['reviewed'] as bool? ?? false,
        ),
    ];
  }
}
