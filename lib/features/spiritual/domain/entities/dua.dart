import 'package:equatable/equatable.dart';

enum DuaCategory { safar, hajj, adhkar, jawami }

/// A supplication from `assets/data/duas.json` (docs/05-content.md).
///
/// Entries with [reviewed] == false must never reach release builds.
class Dua extends Equatable {
  const Dua({
    required this.id,
    required this.category,
    required this.title,
    required this.text,
    required this.isQuranic,
    required this.source,
    this.note,
    this.repeat = 1,
    this.audioAsset,
    this.durationSec,
    required this.reviewed,
  });

  final String id;
  final DuaCategory category;
  final String title;
  final String text;
  final bool isQuranic;
  final String source;
  final String? note;
  final int repeat;
  final String? audioAsset;
  final int? durationSec;
  final bool reviewed;

  @override
  List<Object?> get props => [
        id,
        category,
        title,
        text,
        isQuranic,
        source,
        note,
        repeat,
        audioAsset,
        durationSec,
        reviewed,
      ];
}
