// Upload the missing document (Figma REQ-05 / REQ-05b): bloc rules over fake
// repository + picker, and the screen states. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/requests/domain/entities/missing_document.dart';
import 'package:seen_booking/features/requests/domain/repositories/missing_document_repository.dart';
import 'package:seen_booking/features/requests/domain/services/document_picker.dart';
import 'package:seen_booking/features/requests/domain/usecases/missing_document_usecases.dart';
import 'package:seen_booking/features/requests/presentation/bloc/missing_document_bloc.dart';
import 'package:seen_booking/features/requests/presentation/screens/upload_missing_document_screen.dart';

final _now = DateTime(2026, 10, 15, 12);

MissingDocumentRequest _request({DateTime? deadline}) => MissingDocumentRequest(
      requestId: 'r1',
      referenceId: 'SB-20476',
      documentTitle: 'صورة جواز واضحة',
      travelerName: 'رقية أحمد الحميري',
      reason: 'الصورة الحالية غير مقروءة.',
      deadline: deadline ?? _now.add(const Duration(hours: 46)),
    );

class _FakeRepo implements MissingDocumentRepository {
  Either<Failure, MissingDocumentRequest> getResult = Right(_request());
  Either<Failure, void> uploadResult = const Right(null);
  int uploads = 0;

  @override
  Future<Either<Failure, MissingDocumentRequest>> getMissingDocument(String requestId) async => getResult;

  @override
  Future<Either<Failure, void>> upload({
    required String requestId,
    required PickedDocument document,
    void Function(double fraction)? onProgress,
  }) async {
    uploads++;
    onProgress?.call(0.68);
    return uploadResult;
  }
}

class _FakePicker implements DocumentPicker {
  Either<Failure, PickedDocument?> result =
      const Right(PickedDocument(path: '/tmp/passport_ruqaya.jpg', fileName: 'passport_ruqaya.jpg', sizeBytes: 1800000));
  DocumentSource? lastSource;

  @override
  Future<Either<Failure, PickedDocument?>> pick(DocumentSource source, {required List<String> allowedExtensions}) async {
    lastSource = source;
    return result;
  }
}

MissingDocumentBloc _bloc(_FakeRepo r, _FakePicker p) => MissingDocumentBloc(
      getMissingDocument: GetMissingDocumentUseCase(r),
      uploadDocument: UploadMissingDocumentUseCase(r),
      pickDocument: PickDocumentUseCase(p),
      clock: () => _now,
    );

Future<MissingDocumentBloc> _ready(_FakeRepo r, _FakePicker p) async {
  final bloc = _bloc(r, p)..add(const MissingDocumentStarted('r1'));
  await bloc.stream.firstWhere((s) => s.status != MissingDocumentStatus.loading);
  return bloc;
}

void main() {
  group('MissingDocumentBloc', () {
    test('loads the request and accepts a valid pick, then uploads', () async {
      final repo = _FakeRepo();
      final picker = _FakePicker();
      final bloc = await _ready(repo, picker);
      addTearDown(bloc.close);
      expect(bloc.state.status, MissingDocumentStatus.ready);

      bloc.add(const MissingDocumentSourceChosen(DocumentSource.camera));
      await bloc.stream.firstWhere((s) => s.picked != null);
      expect(picker.lastSource, DocumentSource.camera);

      bloc.add(const MissingDocumentSubmitted());
      final done = await bloc.stream.firstWhere((s) => s.submitted);
      expect(repo.uploads, 1);
      expect(done.uploading, false);
    });

    test('a file over the limit or of a wrong type is rejected before upload', () async {
      final repo = _FakeRepo();
      final picker = _FakePicker()
        ..result = const Right(PickedDocument(path: '/x.jpg', fileName: 'x.jpg', sizeBytes: 9 * 1024 * 1024));
      final bloc = await _ready(repo, picker);
      addTearDown(bloc.close);

      bloc.add(const MissingDocumentSourceChosen(DocumentSource.file));
      var s = await bloc.stream.firstWhere((s) => s.issue != null);
      expect(s.issue!.kind, DocumentIssueKind.tooLarge);
      expect(s.picked, isNull);

      picker.result = const Right(PickedDocument(path: '/x.exe', fileName: 'x.exe', sizeBytes: 10));
      bloc.add(const MissingDocumentSourceChosen(DocumentSource.file));
      s = await bloc.stream.firstWhere((s) => s.issue?.kind == DocumentIssueKind.wrongType);
      expect(repo.uploads, 0);
    });

    test('a cancelled pick changes nothing; a picker failure is reported', () async {
      final repo = _FakeRepo();
      final picker = _FakePicker()..result = const Right(null);
      final bloc = await _ready(repo, picker);
      addTearDown(bloc.close);

      bloc.add(const MissingDocumentSourceChosen(DocumentSource.file));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.picked, isNull);
      expect(bloc.state.issue, isNull);

      picker.result = const Left(ServerFailure('denied', code: 'PICKER_UNAVAILABLE'));
      bloc.add(const MissingDocumentSourceChosen(DocumentSource.camera));
      final s = await bloc.stream.firstWhere((s) => s.issue != null);
      expect(s.issue!.kind, DocumentIssueKind.pickerUnavailable);
    });

    test('an offline failure keeps the file so the user can retry', () async {
      final repo = _FakeRepo()..uploadResult = const Left(NetworkFailure('x'));
      final bloc = await _ready(repo, _FakePicker());
      addTearDown(bloc.close);
      bloc.add(const MissingDocumentSourceChosen(DocumentSource.file));
      await bloc.stream.firstWhere((s) => s.picked != null);

      bloc.add(const MissingDocumentSubmitted());
      var s = await bloc.stream.firstWhere((s) => s.issue != null);
      expect(s.issue!.kind, DocumentIssueKind.offline);
      expect(s.picked, isNotNull);

      repo.uploadResult = const Right(null);
      bloc.add(const MissingDocumentSubmitted());
      s = await bloc.stream.firstWhere((s) => s.submitted);
      expect(repo.uploads, 2);
    });

    test('a deadline already past, or reported by the server, blocks the upload', () async {
      final repo = _FakeRepo()..getResult = Right(_request(deadline: _now.subtract(const Duration(minutes: 1))));
      final bloc = await _ready(repo, _FakePicker());
      addTearDown(bloc.close);
      expect(bloc.state.deadlinePassed, true);
      bloc.add(const MissingDocumentSourceChosen(DocumentSource.file));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.picked, isNull);

      final repo2 = _FakeRepo()
        ..uploadResult = const Left(ServerFailure('late', code: DocumentIssue.deadlinePassedCode));
      final bloc2 = await _ready(repo2, _FakePicker());
      addTearDown(bloc2.close);
      bloc2.add(const MissingDocumentSourceChosen(DocumentSource.file));
      await bloc2.stream.firstWhere((s) => s.picked != null);
      bloc2.add(const MissingDocumentSubmitted());
      final s = await bloc2.stream.firstWhere((s) => s.deadlinePassed);
      expect(s.submitted, false);
    });

    test('a failed load reports loadFailed', () async {
      final repo = _FakeRepo()..getResult = const Left(NetworkFailure('x'));
      final bloc = await _ready(repo, _FakePicker());
      addTearDown(bloc.close);
      expect(bloc.state.status, MissingDocumentStatus.loadFailed);
    });
  });

  group('UploadMissingDocumentScreen', () {
    late _FakeRepo repo;
    late _FakePicker picker;

    Future<void> open(WidgetTester tester, {Widget Function(Widget screen)? wrap}) async {
      repo = _FakeRepo();
      picker = _FakePicker();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final screen = UploadMissingDocumentScreen(requestId: 'r1', createBloc: () => _bloc(repo, picker));
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
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => screen)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('shows what and why, the deadline, the tips and the three sources', (tester) async {
      await open(tester);
      expect(find.text('مستند مطلوب'), findsOneWidget);
      expect(find.text('SB-20476'), findsOneWidget);
      expect(find.text('صورة جواز واضحة'), findsOneWidget);
      expect(find.text('المسافر: رقية أحمد الحميري'), findsOneWidget);
      expect(find.text('المهلة المتبقية للرفع'), findsOneWidget);
      expect(find.text('حتى 5MB'), findsOneWidget);
      for (final s in ['ملف', 'المعرض', 'الكاميرا']) {
        expect(find.text(s), findsOneWidget);
      }
    });

    testWidgets('pick → preview → send closes the screen with true', (tester) async {
      await open(tester);
      await tester.tap(find.text('الكاميرا'));
      await settle(tester);
      expect(picker.lastSource, DocumentSource.camera);
      expect(find.textContaining('passport_ruqaya.jpg'), findsOneWidget);
      expect(find.text('إرسال المستند'), findsOneWidget);
      expect(find.text('استبدال'), findsOneWidget);

      await tester.tap(find.text('إرسال المستند'));
      await settle(tester);
      expect(repo.uploads, 1);
      expect(find.text('open'), findsOneWidget); // popped back
    });

    testWidgets('remove returns to the sources; a too-large file shows the red banner', (tester) async {
      await open(tester);
      await tester.tap(find.text('ملف'));
      await settle(tester);
      await tester.tap(find.text('إزالة'));
      await settle(tester);
      expect(find.text('الكاميرا'), findsOneWidget);

      picker.result = const Right(PickedDocument(path: '/b.jpg', fileName: 'b.jpg', sizeBytes: 9 * 1024 * 1024));
      await tester.tap(find.text('ملف'));
      await settle(tester);
      expect(find.text('الملف أكبر من 5MB. اختر ملفًا أصغر أو صوّر من جديد.'), findsOneWidget);
      expect(repo.uploads, 0);
    });

    testWidgets('an offline failure shows the retry banner and retry sends again', (tester) async {
      await open(tester);
      await tester.tap(find.text('ملف'));
      await settle(tester);
      repo.uploadResult = const Left(NetworkFailure('x'));
      await tester.tap(find.text('إرسال المستند'));
      await settle(tester);
      expect(find.text('تعذّر رفع الملف. تحقق من الاتصال وحاول مجددًا.'), findsOneWidget);

      repo.uploadResult = const Right(null);
      await tester.tap(find.text('إعادة المحاولة'));
      await settle(tester);
      expect(repo.uploads, 2);
    });
  });
}
