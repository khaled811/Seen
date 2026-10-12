import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/tasbeeh.dart';
import '../../domain/repositories/tasbeeh_repository.dart';

/// The tasbeeh phrases from `assets/data/tasbeeh_adhkar.json`.
class JsonDhikrCatalog implements DhikrCatalog {
  JsonDhikrCatalog({
    AssetBundle? bundle,
    this.assetPath = 'assets/data/tasbeeh_adhkar.json',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;

  List<TasbeehDhikr>? _cache;

  @override
  Future<Either<Failure, List<TasbeehDhikr>>> adhkar() async {
    try {
      final list = _cache ??= _parse(await _bundle.loadString(assetPath));
      if (list.isEmpty) return const Left(CacheFailure('No adhkar available'));
      return Right(list);
    } catch (e) {
      return Left(CacheFailure('Could not load adhkar: $e'));
    }
  }

  static List<TasbeehDhikr> _parse(String source) {
    final list = jsonDecode(source) as List;
    return [
      for (final e in list.cast<Map<String, Object?>>())
        TasbeehDhikr(id: e['id']! as String, label: e['label']! as String),
    ];
  }
}
