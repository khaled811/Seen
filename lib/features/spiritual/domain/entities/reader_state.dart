import 'package:equatable/equatable.dart';

import 'bookmark.dart';
import 'last_read.dart';

/// Everything about the reader that survives an app kill.
class ReaderState extends Equatable {
  const ReaderState({
    this.bookmarks = const [],
    this.lastRead,
    this.fontStep = defaultFontStep,
  });

  /// Reader font sizes (sp), docs/03 §3.
  static const fontSizes = [24.0, 27.0, 30.0, 34.0, 38.0, 42.0];
  static const defaultFontStep = 2;

  /// Newest first.
  final List<Bookmark> bookmarks;
  final LastRead? lastRead;
  final int fontStep;

  double get fontSize => fontSizes[fontStep];

  bool hasBookmark(int surah, int ayah) =>
      bookmarks.any((b) => b.isAt(surah, ayah));

  @override
  List<Object?> get props => [bookmarks, lastRead, fontStep];
}
