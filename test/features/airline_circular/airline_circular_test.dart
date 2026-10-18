// REQ-15 / REQ-15b airline circular: approval picker and the auto-filled form. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/airline_circular/domain/entities/airline_circular.dart';
import 'package:seen_booking/features/airline_circular/domain/repositories/airline_circular_repository.dart';
import 'package:seen_booking/features/airline_circular/presentation/bloc/airline_circular_cubit.dart';
import 'package:seen_booking/features/airline_circular/presentation/bloc/approval_picker_cubit.dart';
import 'package:seen_booking/features/airline_circular/presentation/screens/airline_circular_screen.dart';
import 'package:seen_booking/features/airline_circular/presentation/widgets/approval_picker_sheet.dart';
import 'package:seen_booking/features/requests/domain/entities/missing_document.dart';
import 'package:seen_booking/features/requests/domain/services/document_picker.dart';

final _a1 = ApprovedSecurityRequest(id: 'a1', reference: 'SB-20451', leadName: 'محمد عبدالله الحميري', travelerCount: 3, issuedAt: DateTime(2026, 10, 2));
final _a2 = ApprovedSecurityRequest(id: 'a2', reference: 'SB-20433', leadName: 'خالد يحيى المقطري', travelerCount: 1, issuedAt: DateTime(2026, 9, 28));

class _Repo implements AirlineCircularRepository {
  List<ApprovedSecurityRequest> list = [_a1, _a2];
  Failure? failure;
  Failure? prefillFailure;
  final submitted = <CircularSubmission>[];
  var submitCalls = 0;

  @override
  Future<Either<Failure, List<ApprovedSecurityRequest>>> approvedRequests() async =>
      failure == null ? Right(list) : Left(failure!);

  @override
  Future<Either<Failure, CircularPrefill>> prefill(String approvalId) async {
    if (prefillFailure != null) return Left(prefillFailure!);
    final a = list.firstWhere((x) => x.id == approvalId);
    return Right(CircularPrefill(
      approval: a,
      travelers: [
        for (var i = 0; i < a.travelerCount; i++) CircularTraveler(name: i == 0 ? a.leadName : 'مسافر ${i + 1}', passportNumber: '0845219$i'),
      ],
    ));
  }

  @override
  Future<Either<Failure, String>> submit(CircularSubmission submission) async {
    submitCalls++;
    submitted.add(submission);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return failure == null ? const Right('c1') : Left(failure!);
  }
}

class _Picker implements DocumentPicker {
  Either<Failure, PickedDocument?> result = const Right(PickedDocument(path: '/t/ticket.pdf', fileName: 'ticket.pdf', sizeBytes: 2048));

  @override
  Future<Either<Failure, PickedDocument?>> pick(DocumentSource source, {required List<String> allowedExtensions}) async => result;
}

final _now = DateTime(2026, 10, 10, 12);

AirlineCircularCubit _cubit(_Repo repo, [_Picker? picker]) => AirlineCircularCubit(repo, () => picker ?? _Picker(), now: () => _now);

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

void main() {
  group('normalizeFlightNumber', () {
    test('accepts airline code and digits, upper-cased', () {
      expect(normalizeFlightNumber('rj 615'), 'RJ 615');
      expect(normalizeFlightNumber(' QR1203 '), 'QR1203');
      expect(normalizeFlightNumber('RJ'), isNull);
      expect(normalizeFlightNumber('615'), isNull);
      expect(normalizeFlightNumber('RJ 61577'), isNull);
      expect(normalizeFlightNumber(''), isNull);
    });
  });

  group('ApprovalPickerCubit', () {
    test('pre-selects the newest, filters by reference or lead, selects', () async {
      final cubit = ApprovalPickerCubit(_Repo());
      await cubit.load();
      expect(cubit.state.status, ApprovalsStatus.loaded);
      expect(cubit.state.selectedId, 'a1');
      cubit.search('20433');
      expect(cubit.state.visible.map((a) => a.id), ['a2']);
      expect(cubit.state.selected, isNull); // The selection is hidden by the filter.
      cubit.select('a2');
      expect(cubit.state.selected?.id, 'a2');
      cubit.search('المقطري');
      expect(cubit.state.visible.length, 1);
      cubit.search('zzz');
      expect(cubit.state.visible, isEmpty);
      await cubit.close();
    });

    test('a failure can be retried; no approvals selects nothing', () async {
      final repo = _Repo()..failure = const NetworkFailure('off');
      final cubit = ApprovalPickerCubit(repo);
      await cubit.load();
      expect(cubit.state.status, ApprovalsStatus.failure);
      repo
        ..failure = null
        ..list = [];
      await cubit.load();
      expect(cubit.state.status, ApprovalsStatus.loaded);
      expect(cubit.state.selectedId, isNull);
      await cubit.close();
    });
  });

  group('AirlineCircularCubit', () {
    test('linking copies the travelers of the approval', () async {
      final cubit = _cubit(_Repo());
      await cubit.link('a1');
      expect(cubit.state.stage, CircularStage.ready);
      expect(cubit.state.prefill!.travelers.length, 3);
      await cubit.close();
    });

    test('a failed prefill can be changed to another approval', () async {
      final repo = _Repo()..prefillFailure = const NetworkFailure('off');
      final cubit = _cubit(repo);
      await cubit.link('a1');
      expect(cubit.state.stage, CircularStage.failure);
      repo.prefillFailure = null;
      await cubit.link('a2');
      expect(cubit.state.stage, CircularStage.ready);
      expect(cubit.state.prefill!.approval.id, 'a2');
      await cubit.close();
    });

    test('changing the approval keeps the ticket and the flight', () async {
      final cubit = _cubit(_Repo());
      await cubit.link('a1');
      await cubit.pickTicket(DocumentSource.file);
      cubit.setFlightNumber('RJ 615');
      await cubit.link('a2');
      expect(cubit.state.ticket?.fileName, 'ticket.pdf');
      expect(cubit.state.flightNumber, 'RJ 615');
      await cubit.close();
    });

    test('ticket: wrong type, too large and refused permission are reported', () async {
      final picker = _Picker();
      final cubit = _cubit(_Repo(), picker);
      picker.result = const Right(PickedDocument(path: '/t/a.docx', fileName: 'a.docx', sizeBytes: 10));
      await cubit.pickTicket(DocumentSource.file);
      expect(cubit.state.ticketError, TicketError.wrongType);
      expect(cubit.state.ticket, isNull);

      picker.result = const Right(PickedDocument(path: '/t/a.pdf', fileName: 'a.pdf', sizeBytes: ticketMaxBytes + 1));
      await cubit.pickTicket(DocumentSource.file);
      expect(cubit.state.ticketError, TicketError.tooLarge);

      picker.result = const Left(ServerFailure('x', code: cameraDeniedCode));
      await cubit.pickTicket(DocumentSource.camera);
      expect(cubit.state.ticketError, TicketError.cameraDenied);

      picker.result = const Right(PickedDocument(path: '/t/ok.jpg', fileName: 'ok.JPG', sizeBytes: 100));
      await cubit.pickTicket(DocumentSource.file);
      expect(cubit.state.ticketError, isNull);
      expect(cubit.state.ticket?.fileName, 'ok.JPG');
      await cubit.close();
    });

    test('a cancelled pick changes nothing', () async {
      final picker = _Picker()..result = const Right(null);
      final cubit = _cubit(_Repo(), picker);
      await cubit.pickTicket(DocumentSource.file);
      expect(cubit.state.ticket, isNull);
      expect(cubit.state.ticketError, isNull);
      await cubit.close();
    });

    test('sending an incomplete circular flags what is missing and sends nothing', () async {
      final repo = _Repo();
      final cubit = _cubit(repo);
      await cubit.link('a1');
      await cubit.submit();
      expect(cubit.state.showErrors, isTrue);
      expect(repo.submitCalls, 0);
      await cubit.close();
    });

    test('a flight date in the past is not accepted; today is', () async {
      final repo = _Repo();
      final cubit = _cubit(repo);
      await cubit.link('a1');
      await cubit.pickTicket(DocumentSource.file);
      cubit.setFlightNumber('RJ 615');
      cubit.setFlightDate(DateTime(2026, 10, 9));
      await cubit.submit();
      expect(repo.submitCalls, 0);
      cubit.setFlightDate(DateTime(2026, 10, 10));
      await cubit.submit();
      expect(repo.submitCalls, 1);
      await cubit.close();
    });

    test('a complete circular is sent once with a normalised flight number', () async {
      final repo = _Repo();
      final cubit = _cubit(repo);
      await cubit.link('a1');
      await cubit.pickTicket(DocumentSource.file);
      cubit.setFlightNumber(' rj 615 ');
      cubit.setFlightDate(DateTime(2026, 10, 18, 9, 30));
      final a = cubit.submit();
      final b = cubit.submit();
      await Future.wait([a, b]);
      expect(repo.submitCalls, 1);
      expect(repo.submitted.single.approvalId, 'a1');
      expect(repo.submitted.single.flightNumber, 'RJ 615');
      expect(repo.submitted.single.flightDate, DateTime(2026, 10, 18));
      expect(cubit.state.submitted, isTrue);
      await cubit.close();
    });

    test('a failed send keeps the form and says so', () async {
      final repo = _Repo();
      final cubit = _cubit(repo);
      await cubit.link('a1');
      await cubit.pickTicket(DocumentSource.file);
      cubit.setFlightNumber('RJ 615');
      cubit.setFlightDate(DateTime(2026, 10, 18));
      repo.failure = const NetworkFailure('off');
      await cubit.submit();
      expect(cubit.state.submitted, isFalse);
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.notice, CircularNotice.failed);
      expect(cubit.state.ticket, isNotNull);
      await cubit.close();
    });
  });

  group('picker sheet', () {
    Future<void> open(WidgetTester tester, _Repo repo, void Function(ApprovedSecurityRequest?) onResult) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async => onResult(await showApprovalPickerSheet(context, createCubit: () => ApprovalPickerCubit(repo))),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the approvals, searches, and links the selected one', (tester) async {
      ApprovedSecurityRequest? chosen;
      await open(tester, _Repo(), (a) => chosen = a);
      expect(find.text('اختر الموافقة الأمنية'), findsOneWidget);
      expect(find.text('موافقة أمنية · SB-20451'), findsOneWidget);
      expect(find.text('محمد عبدالله الحميري · ٣ مسافرين'), findsOneWidget);
      expect(find.text('صدرت ٢ أكتوبر'), findsOneWidget);
      expect(find.text('خالد يحيى المقطري · مسافر واحد'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'المقطري');
      await tester.pumpAndSettle();
      expect(find.text('موافقة أمنية · SB-20451'), findsNothing);
      await tester.tap(find.text('موافقة أمنية · SB-20433'));
      await tester.pump();
      await tester.tap(find.text('ربط ومتابعة'));
      await tester.pumpAndSettle();
      expect(chosen?.id, 'a2');
    });

    testWidgets('no approvals: a message and Link stays off', (tester) async {
      ApprovedSecurityRequest? chosen;
      await open(tester, _Repo()..list = [], (a) => chosen = a);
      expect(find.text('لا توجد موافقات أمنية صادرة بعد.'), findsOneWidget);
      await tester.tap(find.text('ربط ومتابعة'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      expect(find.text('اختر الموافقة الأمنية'), findsOneWidget);
    });

    testWidgets('a load failure offers retry', (tester) async {
      final repo = _Repo()..failure = const NetworkFailure('off');
      await open(tester, repo, (_) {});
      expect(find.text('تعذّر تحميل الموافقات.'), findsOneWidget);
      repo.failure = null;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('موافقة أمنية · SB-20451'), findsOneWidget);
    });
  });

  group('circular screen', () {
    Future<_Repo> pump(WidgetTester tester) async {
      final repo = _Repo();
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(AirlineCircularScreen(
        createCubit: () => _cubit(repo),
        createPickerCubit: () => ApprovalPickerCubit(repo),
        now: () => _now,
      )));
      await tester.pumpAndSettle(); // The picker opens by itself.
      await tester.tap(find.text('ربط ومتابعة'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('after linking, the travelers are filled and locked, with the ticket and the flight to enter', (tester) async {
      await pump(tester);
      expect(find.text('تعميم شركة طيران'), findsOneWidget);
      expect(find.text('مرتبط بـ SB-20451'), findsOneWidget);
      expect(find.text('موافقة أمنية صادرة · SB-20451'), findsOneWidget);
      expect(find.text('بيانات المسافرين معبّأة تلقائيًا'), findsOneWidget);
      expect(find.text('محمد عبدالله الحميري'), findsOneWidget);
      expect(find.text('08452190'), findsOneWidget);
      expect(find.textContaining('مقفلة'), findsOneWidget);
      expect(find.text('أرفق تذكرة الطيران'), findsOneWidget);
      expect(find.text('رقم الرحلة'), findsOneWidget);
      // Locked fields cannot be edited.
      final locked = tester.widgetList<TextField>(find.byType(TextField)).where((f) => f.readOnly).length;
      expect(locked, greaterThanOrEqualTo(6));
    });

    testWidgets('sending with nothing entered flags the ticket, the flight and the date', (tester) async {
      final repo = await pump(tester);
      await tester.tap(find.text('إرسال التعميم'));
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 0);
      expect(find.text('أرفق تذكرة الطيران.'), findsOneWidget);
      expect(find.text('اكتب رقم رحلة صحيحًا مثل RJ 615.'), findsOneWidget);
      expect(find.text('اختر تاريخ الرحلة.'), findsOneWidget);
    });

    testWidgets('closing the picker without a choice leaves the screen', (tester) async {
      final repo = _Repo();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => AirlineCircularScreen(createCubit: () => _cubit(repo), createPickerCubit: () => ApprovalPickerCubit(repo)),
          )),
          child: const Text('go'),
        ),
      )));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('اختر الموافقة الأمنية'), findsOneWidget);
      await tester.tapAt(const Offset(195, 20)); // The scrim.
      await tester.pumpAndSettle();
      expect(find.text('go'), findsOneWidget);
      expect(find.text('تعميم شركة طيران'), findsNothing);
    });
  });
}
