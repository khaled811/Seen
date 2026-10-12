import 'package:equatable/equatable.dart';

enum QuranIndexTab { surahs, juz, bookmarks }

sealed class QuranIndexEvent extends Equatable {
  const QuranIndexEvent();

  @override
  List<Object?> get props => [];
}

/// Load the Quran and the reader state.
class QuranIndexStarted extends QuranIndexEvent {
  const QuranIndexStarted();
}

/// Re-read bookmarks / last read (after returning from the reader).
class QuranIndexRefreshed extends QuranIndexEvent {
  const QuranIndexRefreshed();
}

class QuranIndexTabChanged extends QuranIndexEvent {
  const QuranIndexTabChanged(this.tab);

  final QuranIndexTab tab;

  @override
  List<Object?> get props => [tab];
}

/// The search text changed. Typing is debounced (150 ms); clearing the field
/// applies immediately.
class QuranIndexQueryChanged extends QuranIndexEvent {
  const QuranIndexQueryChanged(this.query, {this.immediate = false});

  final String query;
  final bool immediate;

  @override
  List<Object?> get props => [query, immediate];
}

/// Remove a bookmark (swipe). Applied to the list at once, then persisted.
class QuranIndexBookmarkRemoved extends QuranIndexEvent {
  const QuranIndexBookmarkRemoved(this.surah, this.ayah);

  final int surah;
  final int ayah;

  @override
  List<Object?> get props => [surah, ayah];
}

/// Undo a swipe-delete, keeping the bookmark's original timestamp.
class QuranIndexBookmarkRestored extends QuranIndexEvent {
  const QuranIndexBookmarkRestored(this.surah, this.ayah, this.createdAt);

  final int surah;
  final int ayah;
  final DateTime createdAt;

  @override
  List<Object?> get props => [surah, ayah, createdAt];
}
