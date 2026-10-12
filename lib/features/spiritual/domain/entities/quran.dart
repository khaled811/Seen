import 'package:equatable/equatable.dart';

enum Revelation { makki, madani }

/// Surah metadata from the bundled Quran dataset (never hand-typed).
class Surah extends Equatable {
  const Surah({
    required this.number,
    required this.nameAr,
    required this.transliteration,
    required this.revelation,
    required this.ayahCount,
    required this.startPage,
  });

  final int number;

  /// Display name without the "سورة" prefix or tashkeel, e.g. "الكهف".
  final String nameAr;
  final String transliteration;
  final Revelation revelation;
  final int ayahCount;
  final int startPage;

  @override
  List<Object?> get props =>
      [number, nameAr, transliteration, revelation, ayahCount, startPage];
}

/// One ayah of the bundled dataset.
class Ayah extends Equatable {
  const Ayah({
    required this.surah,
    required this.number,
    required this.text,
    required this.page,
    required this.juz,
    required this.hizb,
    this.sajda = false,
  });

  final int surah;
  final int number;

  /// Uthmani text, byte-for-byte from the dataset (see data mapper for the
  /// two display-level adjustments: BOM and the embedded basmala header).
  final String text;

  /// Madinah mushaf page, 1..604.
  final int page;

  /// Juz, 1..30.
  final int juz;

  /// Hizb quarter (rub' al-hizb), 1..240.
  final int hizb;
  final bool sajda;

  @override
  List<Object?> get props => [surah, number, text, page, juz, hizb, sajda];
}
