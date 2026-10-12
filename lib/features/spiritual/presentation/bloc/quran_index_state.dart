import 'package:equatable/equatable.dart';

import '../../domain/entities/quran.dart';
import 'quran_index_event.dart';

/// One row of the index list (a surah, a juz or a bookmark).
class QuranIndexRow extends Equatable {
  const QuranIndexRow({
    required this.number,
    required this.title,
    required this.meta,
    required this.page,
    required this.surah,
    required this.ayah,
    this.latin = '',
    this.revelation,
    this.highlighted = false,
    this.bookmarkedAtMs,
  });

  /// Badge number (surah number, juz number or 1-based position).
  final int number;
  final String title;

  /// Transliteration shown LTR next to the title (empty for bookmarks).
  final String latin;
  final String meta;

  /// Makki / Madani icon, only for surah rows.
  final Revelation? revelation;
  final int page;
  final bool highlighted;

  /// Where the row opens in the reader.
  final int surah;
  final int ayah;

  /// Set on bookmark rows: lets a swipe-delete be undone with the original
  /// timestamp.
  final int? bookmarkedAtMs;

  @override
  List<Object?> get props => [
        number,
        title,
        latin,
        meta,
        revelation,
        page,
        highlighted,
        surah,
        ayah,
        bookmarkedAtMs,
      ];
}

/// "آخر قراءة" card content.
class LastReadSummary extends Equatable {
  const LastReadSummary({
    required this.surah,
    required this.ayah,
    required this.surahName,
    required this.page,
    required this.juz,
  });

  final int surah;
  final int ayah;
  final String surahName;
  final int page;
  final int juz;

  @override
  List<Object?> get props => [surah, ayah, surahName, page, juz];
}

sealed class QuranIndexState extends Equatable {
  const QuranIndexState();

  @override
  List<Object?> get props => [];
}

class QuranIndexLoading extends QuranIndexState {
  const QuranIndexLoading();
}

class QuranIndexFailure extends QuranIndexState {
  const QuranIndexFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class QuranIndexLoaded extends QuranIndexState {
  const QuranIndexLoaded({
    required this.tab,
    required this.query,
    required this.rows,
    required this.lastRead,
  });

  final QuranIndexTab tab;
  final String query;
  final List<QuranIndexRow> rows;
  final LastReadSummary? lastRead;

  bool get isSearching => query.trim().isNotEmpty;

  @override
  List<Object?> get props => [tab, query, rows, lastRead];
}
