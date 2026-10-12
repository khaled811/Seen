import 'package:equatable/equatable.dart';

/// Progress of today's Quran reading goal ("وِردك اليومي").
class ReadingProgress extends Equatable {
  const ReadingProgress({
    required this.surahName,
    required this.page,
    required this.pagesRead,
    required this.pagesGoal,
  }) : assert(pagesGoal > 0);

  final String surahName;

  /// Mushaf page the reader will resume on.
  final int page;
  final int pagesRead;
  final int pagesGoal;

  /// 0..1.
  double get fraction => (pagesRead / pagesGoal).clamp(0.0, 1.0);
  int get percent => (fraction * 100).round();

  @override
  List<Object?> get props => [surahName, page, pagesRead, pagesGoal];
}
