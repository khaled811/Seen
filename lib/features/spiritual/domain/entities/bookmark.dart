import 'package:equatable/equatable.dart';

/// A saved reading position.
class Bookmark extends Equatable {
  const Bookmark({
    required this.surah,
    required this.ayah,
    required this.createdAt,
  });

  final int surah;
  final int ayah;
  final DateTime createdAt;

  bool isAt(int surahNumber, int ayahNumber) =>
      surah == surahNumber && ayah == ayahNumber;

  @override
  List<Object?> get props => [surah, ayah, createdAt];
}
