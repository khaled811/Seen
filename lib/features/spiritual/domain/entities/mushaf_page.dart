import 'package:equatable/equatable.dart';

/// One page of the Madinah mushaf (1..604) and the ayah range it holds.
class MushafPage extends Equatable {
  const MushafPage({
    required this.number,
    required this.juz,
    required this.firstSurah,
    required this.firstAyah,
    required this.lastSurah,
    required this.lastAyah,
  });

  final int number;
  final int juz;
  final int firstSurah;
  final int firstAyah;
  final int lastSurah;
  final int lastAyah;

  @override
  List<Object?> get props =>
      [number, juz, firstSurah, firstAyah, lastSurah, lastAyah];
}
