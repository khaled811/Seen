import '../data/repositories/json_quran_repository.dart';
import '../data/repositories/reader_state_repository_impl.dart';
import '../data/repositories/reader_view_prefs_repository_impl.dart';
import '../domain/repositories/quran_repository.dart';
import '../domain/repositories/reader_state_repository.dart';
import '../domain/repositories/reader_view_prefs_repository.dart';
import '../domain/usecases/quran_usecases.dart';
import '../domain/usecases/reader_view_usecases.dart';

/// Composition root for the Quran feature. The repositories are app-wide
/// singletons on purpose: the parsed Quran (~1.7 MB) and the reader state
/// (bookmarks, last read, font size) are shared by the index, the reader, the
/// search screen and the dashboard.
///
/// Tests replace [instance] with fakes.
class QuranModule {
  QuranModule({
    QuranRepository? quran,
    ReaderStateRepository? readerState,
    ReaderViewPrefsRepository? viewPrefs,
  })  : quran = quran ?? JsonQuranRepository(),
        readerState = readerState ?? ReaderStateRepositoryImpl(),
        viewPrefs = viewPrefs ?? ReaderViewPrefsRepositoryImpl();

  static QuranModule instance = QuranModule();

  final QuranRepository quran;
  final ReaderStateRepository readerState;
  final ReaderViewPrefsRepository viewPrefs;

  LoadQuranUseCase get loadQuran => LoadQuranUseCase(quran);
  GetReaderStateUseCase get getReaderState => GetReaderStateUseCase(readerState);
  ToggleBookmarkUseCase get toggleBookmark => ToggleBookmarkUseCase(readerState);
  SaveLastReadUseCase get saveLastRead => SaveLastReadUseCase(readerState);
  SaveFontStepUseCase get saveFontStep => SaveFontStepUseCase(readerState);
  LoadReaderViewPrefsUseCase get loadViewPrefs =>
      LoadReaderViewPrefsUseCase(viewPrefs);
  SaveReaderViewPrefsUseCase get saveViewPrefs =>
      SaveReaderViewPrefsUseCase(viewPrefs);
}
