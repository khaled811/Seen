import 'package:equatable/equatable.dart';

import 'quran.dart';

/// A full-text search hit.
class AyahMatch extends Equatable {
  const AyahMatch({required this.surah, required this.ayah});

  final Surah surah;
  final Ayah ayah;

  @override
  List<Object?> get props => [surah, ayah];
}
