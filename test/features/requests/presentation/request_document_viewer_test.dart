// Document viewer (Figma REQ-11 / REQ-11b): bloc rules over fakes, and the
// screen states (ready / not ready / failed). PDF rendering itself (pdfx) is
// native and is checked on a device; the screen is tested through its pages seam.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/requests/domain/entities/request_detail.dart';
import 'package:seen_booking/features/requests/domain/entities/request_document.dart';
import 'package:seen_booking/features/requests/domain/repositories/document_file_repository.dart';
import 'package:seen_booking/features/requests/domain/services/document_exporter.dart';
import 'package:seen_booking/features/requests/domain/services/pdf_page_renderer.dart';
import 'package:seen_booking/features/requests/presentation/widgets/document_pages_view.dart';
import 'package:seen_booking/features/requests/domain/usecases/request_document_usecases.dart';
import 'package:seen_booking/features/requests/presentation/bloc/document_viewer_bloc.dart';
import 'package:seen_booking/features/requests/presentation/screens/request_document_viewer_screen.dart';

class _Repo implements DocumentFileRepository {
  Either<Failure, Uint8List> result = Right(Uint8List.fromList([1, 2, 3]));
  int fetches = 0;
  final fileIds = <String>[];

  @override
  Future<Either<Failure, Uint8List>> fetch(String url) async {
    fetches++;
    return result;
  }

  @override
  Future<Either<Failure, Uint8List>> fetchFile(String fileId) async {
    fetches++;
    fileIds.add(fileId);
    return result;
  }
}

class _Exporter implements DocumentExporter {
  Either<Failure, bool> saveResult = const Right(true);
  Either<Failure, bool> shareResult = const Right(true);
  String? savedName;
  String? sharedName;

  @override
  Future<Either<Failure, bool>> save(String fileName, Uint8List bytes) async {
    savedName = fileName;
    return saveResult;
  }

  @override
  Future<Either<Failure, bool>> share(String fileName, Uint8List bytes) async {
    sharedName = fileName;
    return shareResult;
  }
}

// A 1x1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01,
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeRenderer implements PdfPageRenderer {
  _FakeRenderer({this.pages = 3, this.failOpen = false});

  final int pages;
  final bool failOpen;
  bool closed = false;
  final rendered = <int>[];

  @override
  Future<int> open(Uint8List bytes) async {
    if (failOpen) throw StateError('not a pdf');
    return pages;
  }

  @override
  Future<Uint8List?> renderPage(int index, {required double scale}) async {
    rendered.add(index);
    return _png;
  }

  @override
  Future<void> close() async => closed = true;
}

DocumentViewerBloc _bloc(_Repo r, _Exporter e) => DocumentViewerBloc(
      fetchDocument: FetchDocumentFileUseCase(r),
      fetchFile: FetchRequestFileUseCase(r),
      saveDocument: SaveDocumentUseCase(e),
      shareDocument: ShareDocumentUseCase(e),
    );

RequestDetail _detail({
  RequestStatus status = RequestStatus.completed,
  String? url = 'https://x.test/visa.pdf',
  List<RequestOutput> outputs = const [],
}) =>
    RequestDetail(
      outputs: outputs,
      id: 'r1',
      referenceId: 'SB-20485',
      serviceName: 'تأشيرة السعودية',
      status: status,
      totalPriceCents: 15000,
      submittedAt: DateTime(2026, 10, 1),
      travelers: const [],
      timeline: const [],
      outputDocumentUrl: url,
    );

void main() {
  test('RequestDocumentKind.fromName tells images from PDFs', () {
    expect(RequestDocumentKind.fromName('https://x.test/a.PNG?sig=1'), RequestDocumentKind.image);
    expect(RequestDocumentKind.fromName('visa.pdf'), RequestDocumentKind.pdf);
    expect(RequestDocumentKind.fromName('no-extension'), RequestDocumentKind.pdf);
  });

  group('DocumentViewerBloc', () {
    test('loads the bytes; a failure reports failed and a retry loads again', () async {
      final repo = _Repo()..result = const Left(NetworkFailure('x'));
      final bloc = _bloc(repo, _Exporter());
      addTearDown(bloc.close);

      bloc.add(const DocumentViewerLoadRequested('u'));
      await bloc.stream.firstWhere((s) => s.status == DocumentViewerStatus.failed);

      repo.result = Right(Uint8List.fromList([9]));
      bloc.add(const DocumentViewerLoadRequested('u'));
      final s = await bloc.stream.firstWhere((s) => s.status == DocumentViewerStatus.ready);
      expect(s.bytes, isNotNull);
      expect(repo.fetches, 2);
    });

    test('save reports saved, stays silent on cancel and reports failures', () async {
      final repo = _Repo();
      final exporter = _Exporter();
      final bloc = _bloc(repo, exporter);
      addTearDown(bloc.close);
      bloc.add(const DocumentViewerLoadRequested('u'));
      await bloc.stream.firstWhere((s) => s.status == DocumentViewerStatus.ready);

      bloc.add(const DocumentViewerSaveRequested('a.pdf'));
      var s = await bloc.stream.firstWhere((s) => s.outcome == DocumentExportOutcome.saved);
      expect(exporter.savedName, 'a.pdf');
      final seq = s.outcomeSeq;

      exporter.saveResult = const Right(false); // cancelled
      bloc.add(const DocumentViewerSaveRequested('a.pdf'));
      await bloc.stream.firstWhere((s) => !s.exporting);
      expect(bloc.state.outcomeSeq, seq);

      exporter.saveResult = const Left(ServerFailure('x'));
      bloc.add(const DocumentViewerSaveRequested('a.pdf'));
      await bloc.stream.firstWhere((s) => s.outcome == DocumentExportOutcome.saveFailed);
    });

    test('a share failure is reported', () async {
      final exporter = _Exporter()..shareResult = const Left(ServerFailure('x'));
      final bloc = _bloc(_Repo(), exporter);
      addTearDown(bloc.close);
      bloc.add(const DocumentViewerLoadRequested('u'));
      await bloc.stream.firstWhere((s) => s.status == DocumentViewerStatus.ready);
      bloc.add(const DocumentViewerShareRequested('a.pdf'));
      await bloc.stream.firstWhere((s) => s.outcome == DocumentExportOutcome.shareFailed);
    });
  });

  group('RequestDocumentViewerScreen', () {
    late _Repo repo;
    late _Exporter exporter;

    Future<void> open(WidgetTester tester, RequestDetail detail, {bool failFetch = false}) async {
      repo = _Repo();
      if (failFetch) repo.result = const Left(NetworkFailure('x'));
      exporter = _Exporter();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        home: RequestDocumentViewerScreen(
          detail: detail,
          createBloc: () => _bloc(repo, exporter),
          pagesBuilder: (context, bytes, kind, onPage, onFail) {
            WidgetsBinding.instance.addPostFrameCallback((_) => onPage(0, 2));
            return const Center(child: Text('PAGES'));
          },
        ),
      ));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('ready: file name, page counter, share and download', (tester) async {
      await open(tester, _detail());
      expect(find.text('تأشيرة السعودية.pdf'), findsOneWidget);
      expect(find.text('صفحة ١ من ٢'), findsOneWidget);
      expect(find.text('PAGES'), findsOneWidget);

      await tester.tap(find.text('تنزيل'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(exporter.savedName, 'تأشيرة السعودية.pdf');
      expect(find.text('تم حفظ الملف.'), findsOneWidget);
    });

    testWidgets('a delivered file is opened by its id (a signed link is asked for, never a stored URL)', (tester) async {
      const output = RequestOutput(fileId: 'file-77', fileName: 'visa-A.pdf', contentType: 'application/pdf', sizeBytes: 900);
      await open(tester, _detail(url: null, outputs: const [output]));
      expect(repo.fileIds, ['file-77']);
      expect(find.text('visa-A.pdf'), findsOneWidget);
      expect(find.text('PAGES'), findsOneWidget);
    });

    testWidgets('a delivered file that fails to open retries with a new request for the link', (tester) async {
      const output = RequestOutput(fileId: 'file-77', fileName: 'visa-A.pdf');
      await open(tester, _detail(url: null, outputs: const [output]), failFetch: true);
      expect(find.text('تعذّر فتح المستند'), findsOneWidget);
      repo.result = Right(Uint8List.fromList([1]));
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();
      expect(repo.fileIds, ['file-77', 'file-77']);
      expect(find.text('PAGES'), findsOneWidget);
    });

    testWidgets('the chosen one of several delivered files is the one opened', (tester) async {
      const second = RequestOutput(fileId: 'file-2', fileName: 'visa-B.pdf');
      repo = _Repo();
      exporter = _Exporter();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        home: RequestDocumentViewerScreen(
          detail: _detail(url: null, outputs: const [RequestOutput(fileId: 'file-1', fileName: 'visa-A.pdf'), second]),
          output: second,
          createBloc: () => _bloc(repo, exporter),
          pagesBuilder: (context, bytes, kind, onPage, onFail) => const Center(child: Text('PAGES')),
        ),
      ));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(repo.fileIds, ['file-2']);
    });

    testWidgets('not ready: no document yet shows the explanation and where the request is', (tester) async {
      await open(tester, _detail(status: RequestStatus.processing, url: null));
      expect(find.text('المستند غير جاهز بعد'), findsOneWidget);
      expect(find.textContaining('٣ من ٥'), findsOneWidget);
      expect(repo.fetches, 0);
      expect(find.text('تنزيل'), findsNothing);
    });

    testWidgets('failed to load: shows the failure card; retry fetches again', (tester) async {
      await open(tester, _detail(), failFetch: true);
      expect(find.text('تعذّر فتح المستند'), findsOneWidget);
      expect(find.text('إبلاغ الدعم'), findsOneWidget);
      expect(find.text('PAGES'), findsNothing);

      repo.result = Right(Uint8List.fromList([1]));
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();
      expect(repo.fetches, 2);
      expect(find.text('PAGES'), findsOneWidget);
    });
  });

  group('DocumentPagesView', () {
    Future<void> pump(
      WidgetTester tester, {
      required RequestDocumentKind kind,
      PdfPageRenderer Function()? create,
      required List<(int, int)> pageEvents,
      required VoidCallback onFail,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DocumentPagesView(
            bytes: _png,
            kind: kind,
            createPdfRenderer: create,
            onPageChanged: (p, t) => pageEvents.add((p, t)),
            onLoadFailed: onFail,
          ),
        ),
      ));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('an image is one page with a zoom pill that steps 100 / 150 / 200%', (tester) async {
      final events = <(int, int)>[];
      await pump(tester, kind: RequestDocumentKind.image, pageEvents: events, onFail: () {});
      expect(events.last, (0, 1));
      expect(find.text('100%'), findsOneWidget);
      await tester.tap(find.text('+'));
      await tester.pump();
      expect(find.text('150%'), findsOneWidget);
      await tester.tap(find.text('+'));
      await tester.pump();
      expect(find.text('200%'), findsOneWidget);
      await tester.tap(find.text('−'));
      await tester.pump();
      expect(find.text('150%'), findsOneWidget);
    });

    testWidgets('a PDF shows thumbnails; selecting one changes the page and resets the zoom', (tester) async {
      final events = <(int, int)>[];
      final renderer = _FakeRenderer(pages: 3);
      await pump(tester, kind: RequestDocumentKind.pdf, create: () => renderer, pageEvents: events, onFail: () {});
      expect(events.last, (0, 3));
      expect(renderer.rendered, contains(0));

      await tester.tap(find.text('+'));
      await tester.pump();
      expect(find.text('150%'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('2'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
      expect(events.last, (1, 3));
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('a PDF that cannot be opened reports the failure and releases the renderer', (tester) async {
      var failed = 0;
      final renderer = _FakeRenderer(failOpen: true);
      await pump(tester, kind: RequestDocumentKind.pdf, create: () => renderer, pageEvents: [], onFail: () => failed++);
      expect(failed, 1);
      expect(renderer.closed, isTrue);
    });

    testWidgets('disposing the view closes the renderer', (tester) async {
      final renderer = _FakeRenderer();
      await pump(tester, kind: RequestDocumentKind.pdf, create: () => renderer, pageEvents: [], onFail: () {});
      await tester.pumpWidget(const SizedBox());
      expect(renderer.closed, isTrue);
    });
  });
}
