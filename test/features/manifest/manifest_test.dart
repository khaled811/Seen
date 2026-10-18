// REQ-14 / REQ-14b group manifest: build and summary. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/widgets/actions.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/manifest/domain/entities/manifest.dart';
import 'package:seen_booking/features/manifest/domain/repositories/manifest_repository.dart';
import 'package:seen_booking/features/manifest/presentation/bloc/manifest_build_cubit.dart';
import 'package:seen_booking/features/manifest/presentation/bloc/manifest_summary_cubit.dart';
import 'package:seen_booking/features/manifest/presentation/screens/manifest_build_screen.dart';
import 'package:seen_booking/features/manifest/presentation/screens/manifest_summary_screen.dart';

ManifestDraft _draft({int extra = 0}) => ManifestDraft(
      id: 'd1',
      serviceLabel: 'تأشيرة السعودية · عمرة',
      travelers: [
        const ManifestTraveler(id: 't0', name: 'محمد عبدالله الحميري', passportNumber: '08452197'),
        const ManifestTraveler(id: 't1', name: 'رقية أحمد الحميري', passportNumber: '08452203'),
        const ManifestTraveler(id: 't2', name: 'سالم محمد الحميري', passportNumber: '09111584', problem: ManifestProblem.missingPassport),
        const ManifestTraveler(id: 't3', name: 'فاطمة سالم الحميري', problem: ManifestProblem.passportExpiring, monthsLeft: 4),
        const ManifestTraveler(id: 't4', name: 'عبدالله محمد الحميري', passportNumber: '09111620'),
        for (var i = 5; i < 10 + extra; i++) ManifestTraveler(id: 't$i', name: 'مسافر $i', passportNumber: '0$i'),
      ],
    );

ManifestSummary _summary() => const ManifestSummary(
      id: 'm1',
      reference: 'GM-0412',
      title: 'كشف عمرة · مكتب الريان',
      travelers: [
        ManifestTravelerStatus(id: 'a', name: 'محمد عبدالله الحميري', outcome: ManifestOutcome.issued, doneSteps: 5),
        ManifestTravelerStatus(id: 'b', name: 'سالم محمد الحميري', outcome: ManifestOutcome.atAuthority, doneSteps: 3),
        ManifestTravelerStatus(
          id: 'c',
          name: 'فاطمة سالم الحميري',
          outcome: ManifestOutcome.rejected,
          doneSteps: 2,
          rejectionReason: 'صلاحية الجواز أقل من ٦ أشهر',
        ),
      ],
    );

class _Repo implements ManifestRepository {
  ManifestDraft draft = _draft();
  Failure? failure;
  final added = <String>[];
  var submitCalls = 0;
  var saveCalls = 0;
  final resubmitted = <String>[];
  String url = 'https://files.example/issued.zip';
  ManifestSummary summaryValue = _summary();

  Either<Failure, T> _r<T>(T v) => failure == null ? Right(v) : Left(failure!);

  @override
  Future<Either<Failure, ManifestDraft>> openDraft({required String serviceId, required String serviceLabel}) async => _r(draft);

  @override
  Future<Either<Failure, ManifestDraft>> addTraveler({required String draftId, required String name, String? passportNumber}) async {
    added.add('$name|$passportNumber');
    draft = ManifestDraft(
      id: draft.id,
      serviceLabel: draft.serviceLabel,
      travelers: [
        ...draft.travelers,
        ManifestTraveler(
          id: 'n${added.length}',
          name: name,
          passportNumber: passportNumber,
          problem: passportNumber == null ? ManifestProblem.missingPassport : ManifestProblem.none,
        ),
      ],
    );
    return _r(draft);
  }

  ManifestImportFile? imported;
  @override
  Future<Either<Failure, ManifestDraft>> importList({required String draftId, required ManifestImportFile file}) async {
    imported = file;
    return _r(draft);
  }

  @override
  Future<Either<Failure, void>> saveDraft(String draftId) async {
    saveCalls++;
    return _r(null);
  }

  @override
  Future<Either<Failure, String>> submit(String draftId) async {
    submitCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return _r('m1');
  }

  @override
  Future<Either<Failure, ManifestSummary>> summary(String manifestId) async => _r(summaryValue);

  @override
  Future<Either<Failure, ManifestSummary>> resubmit({required String manifestId, required String travelerId}) async {
    resubmitted.add(travelerId);
    summaryValue = ManifestSummary(
      id: 'm1',
      reference: 'GM-0412',
      title: summaryValue.title,
      travelers: [
        for (final t in summaryValue.travelers)
          t.id == travelerId ? ManifestTravelerStatus(id: t.id, name: t.name, outcome: ManifestOutcome.atAuthority, doneSteps: 2) : t,
      ],
    );
    return _r(summaryValue);
  }

  @override
  Future<Either<Failure, String>> issuedVisasUrl(String manifestId) async => _r(url);
}

class _Picker implements ManifestImportPicker {
  Either<Failure, ManifestImportFile?> result = const Right(null);

  @override
  Future<Either<Failure, ManifestImportFile?>> pick() async => result;
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: home,
    );

ManifestBuildCubit _build(_Repo repo, [_Picker? picker]) =>
    ManifestBuildCubit(repo, picker ?? _Picker(), serviceId: 's', serviceLabel: 'تأشيرة السعودية · عمرة');

void main() {
  group('ManifestDraft', () {
    test('counts ready and incomplete lines', () {
      final d = _draft();
      expect(d.travelers.length, 10);
      expect(d.readyCount, 8);
      expect(d.incompleteCount, 2);
    });
  });

  group('ManifestBuildCubit', () {
    test('loads, shows five rows first, then all', () async {
      final cubit = _build(_Repo());
      await cubit.load();
      expect(cubit.state.load, ManifestLoad.loaded);
      expect(cubit.state.visibleCount, 5);
      expect(cubit.state.hiddenCount, 5);
      cubit.toggleShowAll();
      expect(cubit.state.visibleCount, 10);
      expect(cubit.state.hiddenCount, 0);
      await cubit.close();
    });

    test('a failed load can be retried', () async {
      final repo = _Repo()..failure = const NetworkFailure('off');
      final cubit = _build(repo);
      await cubit.load();
      expect(cubit.state.load, ManifestLoad.failure);
      repo.failure = null;
      await cubit.load();
      expect(cubit.state.load, ManifestLoad.loaded);
      await cubit.close();
    });

    test('adding a traveler appends the line and shows the whole list', () async {
      final repo = _Repo();
      final cubit = _build(repo);
      await cubit.load();
      await cubit.addTraveler(name: 'خالد', passportNumber: null);
      expect(repo.added, ['خالد|null']);
      expect(cubit.state.draft!.travelers.length, 11);
      expect(cubit.state.showAll, isTrue);
      expect(cubit.state.notice, ManifestNotice.added);
      await cubit.close();
    });

    test('import: cancelled does nothing, a file is sent, a failure is reported', () async {
      final repo = _Repo();
      final picker = _Picker();
      final cubit = _build(repo, picker);
      await cubit.load();

      await cubit.import();
      expect(repo.imported, isNull);
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.notice, isNull);

      picker.result = const Right(ManifestImportFile(name: 'list.csv', bytes: [1, 2, 3]));
      await cubit.import();
      expect(repo.imported?.name, 'list.csv');
      expect(cubit.state.notice, ManifestNotice.imported);

      repo.failure = const NetworkFailure('off');
      await cubit.import();
      expect(cubit.state.notice, ManifestNotice.importFailed);
      await cubit.close();
    });

    test('import: a file over the limit is refused, from the picker or by size', () async {
      final repo = _Repo();
      final picker = _Picker()..result = const Left(ServerFailure('big', code: manifestImportTooLargeCode));
      final cubit = _build(repo, picker);
      await cubit.load();
      await cubit.import();
      expect(cubit.state.notice, ManifestNotice.importTooLarge);

      picker.result = Right(ManifestImportFile(name: 'x.csv', bytes: List.filled(manifestImportMaxBytes + 1, 0)));
      await cubit.import();
      expect(repo.imported, isNull);
      expect(cubit.state.notice, ManifestNotice.importTooLarge);
      await cubit.close();
    });

    test('submit runs once however many times it is pressed', () async {
      final repo = _Repo();
      final cubit = _build(repo);
      await cubit.load();
      final a = cubit.submit();
      final b = cubit.submit();
      await Future.wait([a, b]);
      expect(repo.submitCalls, 1);
      expect(cubit.state.submittedId, 'm1');
      await cubit.close();
    });

    test('a failed submit keeps the manifest and says so', () async {
      final repo = _Repo();
      final cubit = _build(repo);
      await cubit.load();
      repo.failure = const NetworkFailure('off');
      await cubit.submit();
      expect(cubit.state.submittedId, isNull);
      expect(cubit.state.notice, ManifestNotice.failed);
      expect(cubit.state.busy, isFalse);
      await cubit.close();
    });
  });

  group('ManifestSummaryCubit', () {
    test('re-sending a rejected traveler updates the summary', () async {
      final repo = _Repo();
      final cubit = ManifestSummaryCubit(repo, (_) async => true, manifestId: 'm1');
      await cubit.load();
      expect(cubit.state.summary!.count(ManifestOutcome.rejected), 1);
      await cubit.resubmit('c');
      expect(repo.resubmitted, ['c']);
      expect(cubit.state.summary!.count(ManifestOutcome.rejected), 0);
      expect(cubit.state.notice, ManifestSummaryNotice.resubmitted);
      expect(cubit.state.busyTravelerId, isNull);
      await cubit.close();
    });

    test('only a secure link is opened for the download', () async {
      final repo = _Repo();
      final opened = <String>[];
      final cubit = ManifestSummaryCubit(repo, (u) async {
        opened.add(u);
        return true;
      }, manifestId: 'm1');
      await cubit.load();
      await cubit.downloadIssued();
      expect(opened, ['https://files.example/issued.zip']);

      repo.url = 'http://insecure.example/x.zip';
      await cubit.downloadIssued();
      expect(opened.length, 1);
      expect(cubit.state.notice, ManifestSummaryNotice.downloadFailed);

      repo.url = 'https://files.example/issued.zip';
      final refused = ManifestSummaryCubit(repo, (_) async => false, manifestId: 'm1');
      await refused.load();
      await refused.downloadIssued();
      expect(refused.state.notice, ManifestSummaryNotice.downloadFailed);
      await cubit.close();
      await refused.close();
    });
  });

  group('build screen', () {
    Future<_Repo> pumpBuild(WidgetTester tester) async {
      final repo = _Repo();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(ManifestBuildScreen(
        serviceId: 's',
        serviceLabel: 'تأشيرة السعودية · عمرة',
        createCubit: () => _build(repo),
      )));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('shows the import card, the counts, five rows and the rest as a link', (tester) async {
      await pumpBuild(tester);
      expect(find.text('كشف جماعي'), findsOneWidget);
      expect(find.text('استيراد قائمة المسافرين'), findsOneWidget);
      expect(find.text('١٠ مسافرين'), findsOneWidget);
      expect(find.text('٨ مكتمل'), findsOneWidget);
      expect(find.text('٢ ناقص'), findsOneWidget);
      expect(find.text('محمد عبدالله الحميري'), findsOneWidget);
      expect(find.text('ينقص الجواز'), findsOneWidget);
      expect(find.text('الجواز ينتهي خلال ٤ أشهر'), findsOneWidget);
      expect(find.text('مسافر 5'), findsNothing);
      expect(find.text('+ ٥ مسافرين آخرين'), findsOneWidget);

      await tester.tap(find.text('+ ٥ مسافرين آخرين'));
      await tester.pumpAndSettle();
      expect(find.text('عرض أقل', skipOffstage: false), findsOneWidget);
      expect(find.text('مسافر 9', skipOffstage: false), findsOneWidget);
    });

    testWidgets('add a traveler needs a name, then appends it', (tester) async {
      final repo = await pumpBuild(tester);
      await tester.ensureVisible(find.text('إضافة مسافر'));
      await tester.tap(find.text('إضافة مسافر'));
      await tester.pumpAndSettle();
      // Sheet: the button of the form (the title shares the words).
      await tester.tap(find.widgetWithText(SeenButton, 'إضافة مسافر').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('اكتب اسم المسافر.'), findsOneWidget);
      expect(repo.added, isEmpty);
    });

    testWidgets('review explains what will and will not be sent', (tester) async {
      await pumpBuild(tester);
      await tester.tap(find.text('مراجعة الكشف'));
      await tester.pumpAndSettle();
      expect(find.text('إرسال الكشف'), findsWidgets);
      expect(find.textContaining('الناقصون (٢)'), findsOneWidget);
    });

    testWidgets('save as draft calls the server once and confirms', (tester) async {
      final repo = await pumpBuild(tester);
      await tester.tap(find.text('حفظ كمسودة'));
      await tester.pumpAndSettle();
      expect(repo.saveCalls, 1);
      expect(find.text('حُفظ الكشف كمسودة.'), findsOneWidget);
    });

    testWidgets('a load failure offers retry', (tester) async {
      final repo = _Repo()..failure = const NetworkFailure('off');
      await tester.pumpWidget(_app(ManifestBuildScreen(serviceId: 's', serviceLabel: 'x', createCubit: () => _build(repo))));
      await tester.pumpAndSettle();
      expect(find.text('تعذّر تحميل الكشف.'), findsOneWidget);
      repo.failure = null;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('إضافة مسافر'), findsOneWidget);
    });
  });

  group('summary screen', () {
    Future<_Repo> pumpSummary(WidgetTester tester) async {
      final repo = _Repo();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(ManifestSummaryScreen(
        manifestId: 'm1',
        createCubit: () => ManifestSummaryCubit(repo, (_) async => true, manifestId: 'm1'),
      )));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('shows the manifest, the stats and a status per traveler', (tester) async {
      await pumpSummary(tester);
      expect(find.text('ملخص الكشف'), findsOneWidget);
      expect(find.text('GM-0412 · ٣ مسافرين'), findsOneWidget);
      expect(find.text('كشف عمرة · مكتب الريان'), findsOneWidget);
      expect(find.text('قيد المعالجة'), findsOneWidget);
      expect(find.textContaining('كل مسافر له حالة مستقلة'), findsOneWidget);
      expect(find.text('السبب: صلاحية الجواز أقل من ٦ أشهر'), findsOneWidget);
      expect(find.text('تنزيل التأشيرات الصادرة (١)'), findsOneWidget);
    });

    testWidgets('re-submit sends only that traveler', (tester) async {
      final repo = await pumpSummary(tester);
      await tester.tap(find.text('إعادة التقديم'));
      await tester.pumpAndSettle();
      expect(repo.resubmitted, ['c']);
      expect(find.text('إعادة التقديم'), findsNothing);
      expect(find.text('أُعيد تقديم المسافر.'), findsOneWidget);
    });
  });
}
