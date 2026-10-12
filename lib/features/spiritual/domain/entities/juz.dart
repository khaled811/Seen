import 'package:equatable/equatable.dart';

/// One of the 30 parts of the Quran and where it begins.
class Juz extends Equatable {
  const Juz({
    required this.number,
    required this.firstSurah,
    required this.firstAyah,
    required this.startPage,
  });

  final int number;
  final int firstSurah;
  final int firstAyah;
  final int startPage;

  @override
  List<Object?> get props => [number, firstSurah, firstAyah, startPage];
}
