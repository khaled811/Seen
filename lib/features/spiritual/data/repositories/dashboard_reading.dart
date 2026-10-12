import '../../domain/entities/quran_data.dart';
import '../../domain/entities/reader_state.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/quran_repository.dart';
import '../../domain/repositories/reader_state_repository.dart';

/// The dashboard's "وِردك اليومي" card: the real last-read surah and page, or
/// the Al-Kahf fixture when no sources are wired (previews, tests).
/// Progress counts stay mocked until daily goals exist.
Future<ReadingProgress> loadReadingProgress({
  ReaderStateRepository? readerState,
  QuranRepository? quran,
}) async {
  const fixture = ReadingProgress(
    surahName: 'الكهف',
    page: 293,
    pagesRead: 3,
    pagesGoal: 5,
  );
  if (readerState == null || quran == null) return fixture;
  final QuranData? data = (await quran.load()).fold((_) => null, (d) => d);
  if (data == null) return fixture;
  final last = (await readerState.load())
      .getOrElse((_) => const ReaderState())
      .lastRead;
  final surah = last?.surah ?? 1;
  final ayah = last?.ayah ?? 1;
  return ReadingProgress(
    surahName: data.surah(surah).nameAr,
    page: data.ayah(surah, ayah)?.page ?? data.surah(surah).startPage,
    pagesRead: 3,
    pagesGoal: 5,
  );
}
