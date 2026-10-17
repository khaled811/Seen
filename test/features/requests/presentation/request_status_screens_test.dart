// Request detail by status (Figma REQ-06 … 09): waiting on the agent / on
// management, rejected, cancelled, expired. The real RequestsBloc over a fake
// repository drives the real RequestDetailScreen. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/requests/data/models/request_detail_dto.dart';
import 'package:seen_booking/features/requests/domain/entities/request_detail.dart';
import 'package:seen_booking/features/requests/domain/entities/request_summary.dart';
import 'package:seen_booking/features/requests/domain/entities/request_traveler_status.dart';
import 'package:seen_booking/features/requests/domain/repositories/requests_repository.dart';
import 'package:seen_booking/features/requests/domain/usecases/cancel_request_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_request_detail_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/remind_approver_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_requests_usecase.dart';
import 'package:seen_booking/features/requests/presentation/bloc/approver_reminder_cubit.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_bloc.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_event.dart';
import 'package:seen_booking/features/requests/presentation/screens/request_detail_screen.dart';
import 'package:seen_booking/features/requests/presentation/widgets/request_status_sections.dart';

final _now = DateTime(2026, 10, 17, 12);

RequestDetail _detail(
  RequestStatus status, {
  RequestApprovalInfo? approval,
  String? rejectionReason,
  RequestCancellationInfo? cancellation,
  int? refundedCents,
  DateTime? slaDeadline,
}) =>
    RequestDetail(
      id: 'r1',
      referenceId: 'SB-20490',
      serviceName: 'حجز طيران',
      status: status,
      totalPriceCents: 124000,
      submittedAt: DateTime(2026, 10, 1),
      travelers: const [
        RequestTravelerStatus(
            name: 'عبدالرحمن فيصل',
            passportNumber: 'A1',
            status: TravelerApprovalStatus.pending),
        RequestTravelerStatus(
            name: 'منى علي',
            passportNumber: 'A2',
            status: TravelerApprovalStatus.pending),
      ],
      timeline: const [],
      approval: approval,
      rejectionReason: rejectionReason,
      cancellation: cancellation,
      refundedCents: refundedCents,
      slaDeadline: slaDeadline,
    );

class _Repo implements RequestsRepository {
  _Repo(this.detail);
  RequestDetail detail;
  int cancels = 0;

  @override
  Future<Either<Failure, List<RequestSummary>>> getRequests() async =>
      const Right([]);

  @override
  Future<Either<Failure, RequestDetail>> getRequestDetail(
          String requestId) async =>
      Right(detail);

  @override
  Future<Either<Failure, RequestDetail>> cancelRequest(String requestId) async {
    cancels++;
    return Right(_detail(RequestStatus.cancelled));
  }

  int reminders = 0;

  /// The first reminder goes through, the next ones are refused as too soon.
  @override
  Future<Either<Failure, void>> remindApprover(String requestId) async {
    reminders++;
    if (reminders > 1) {
      return const Left(ServerFailure('x',
          code: 'RATE_LIMITED', details: {'retryAfterSeconds': 3600}));
    }
    return const Right(null);
  }
}

Future<void> settle(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    InjectionContainer.instance.init();
  });

  group('hasStatusSection / isExpiredByDeadline', () {
    test(
        'covers the approval, rejected and cancelled statuses and the lapsed deadline',
        () {
      expect(
          hasStatusSection(_detail(RequestStatus.pendingAgentApproval)), true);
      expect(hasStatusSection(_detail(RequestStatus.pendingManagementApproval)),
          true);
      expect(hasStatusSection(_detail(RequestStatus.rejected)), true);
      expect(hasStatusSection(_detail(RequestStatus.cancelled)), true);
      expect(hasStatusSection(_detail(RequestStatus.processing)), false);
      expect(hasStatusSection(_detail(RequestStatus.completed)), false);
      expect(
        hasStatusSection(
            _detail(RequestStatus.infoRequired,
                slaDeadline: _now.subtract(const Duration(hours: 1))),
            now: _now),
        true,
      );
      expect(
        hasStatusSection(
            _detail(RequestStatus.infoRequired,
                slaDeadline: _now.add(const Duration(hours: 5))),
            now: _now),
        false,
      );
    });
  });

  group('RequestApprovalDto / RequestCancellationDto', () {
    test('map the wire shape', () {
      final a = RequestApprovalDto.fromJson(const {
        'kind': 'MANAGEMENT',
        'approverName': 'إدارة',
        'typicalWaitMinutes': 1440,
        'thresholdAmount': '2000.00',
      }).toEntity();
      expect((a.kind, a.thresholdCents, a.typicalWaitMinutes),
          (ApproverKind.management, 200000, 1440));
      expect(
          RequestApprovalDto.fromJson(const {'kind': 'MASTER_AGENT'})
              .toEntity()
              .kind,
          ApproverKind.masterAgent);
      final c = RequestCancellationDto.fromJson(
          const {'reason': 'x', 'code': 'DEADLINE_EXPIRED'}).toEntity();
      expect(c.expiredByDeadline, true);
    });
  });

  group('RequestDetailScreen', () {
    late _Repo repo;

    Future<void> open(WidgetTester tester, RequestDetail detail) async {
      repo = _Repo(detail);
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bloc = RequestsBloc(
        getRequestsUseCase: GetRequestsUseCase(repo),
        getRequestDetailUseCase: GetRequestDetailUseCase(repo),
        cancelRequestUseCase: CancelRequestUseCase(repo),
      )..add(const RequestsLoadRequested());
      addTearDown(() => bloc.close().ignore());
      await settle(tester);
      bloc.add(RequestDetailRequested(detail.id));
      await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light,
          home: RequestDetailScreen(
            createReminderCubit: () => ApproverReminderCubit(
                remindApprover: RemindApproverUseCase(repo)),
          ),
        ),
      ));
      await settle(tester);
    }

    testWidgets(
        'waiting on the main agent: card, who approves, why, remind / cancel',
        (tester) async {
      await open(
        tester,
        _detail(
          RequestStatus.pendingAgentApproval,
          approval: const RequestApprovalInfo(
            kind: ApproverKind.masterAgent,
            approverName: 'مكتب الريان',
            typicalWaitMinutes: 120,
          ),
        ),
      );
      expect(find.text('بانتظار موافقة الوكيل'), findsOneWidget);
      expect(find.textContaining('حجز طيران · مسافران'), findsOneWidget);
      expect(find.text('من يوافق؟'), findsOneWidget);
      expect(find.text('يوافق عليه: مكتب الريان (الوكيل الرئيسي)'),
          findsOneWidget);
      expect(find.text('الوقت المتوقع: ساعتين'), findsOneWidget);
      expect(find.textContaining('يحتاج موافقة وكيلك الرئيسي'), findsOneWidget);
      expect(find.text('تذكير الموافق'), findsOneWidget);
      expect(find.text('إلغاء الطلب'), findsWidgets);
    });

    testWidgets(
        'waiting on management names the threshold and the expected time',
        (tester) async {
      await open(
        tester,
        _detail(
          RequestStatus.pendingManagementApproval,
          approval: const RequestApprovalInfo(
            kind: ApproverKind.management,
            typicalWaitMinutes: 1440,
            thresholdCents: 200000,
          ),
        ),
      );
      expect(find.text('بانتظار موافقة الإدارة'), findsOneWidget);
      expect(find.text('يوافق عليه: إدارة جُباري'), findsOneWidget);
      expect(find.text('الوقت المتوقع: ٢٤ ساعة'), findsOneWidget);
      expect(find.textContaining('2,000.00'), findsOneWidget);
    });

    testWidgets(
        'remind sends once; a second tap within the session is refused as too soon',
        (tester) async {
      await open(
        tester,
        _detail(RequestStatus.pendingAgentApproval,
            approval:
                const RequestApprovalInfo(kind: ApproverKind.masterAgent)),
      );
      // The real (placeholder) endpoint fails first, then the debug fallback answers.
      Future<void> wait() async {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await tester.tap(find.text('تذكير الموافق'));
      await wait();
      expect(find.text('أُرسل التذكير إلى الموافق.'), findsOneWidget);
      // The confirmation snackbar covers the sticky bar: dismiss it first.
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
          .hideCurrentSnackBar();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('تذكير الموافق'));
      await wait();
      await tester.pump(const Duration(
          seconds: 1)); // the first snackbar leaves, the second shows
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('ذكّرته مؤخرًا'), findsOneWidget);
    });

    testWidgets(
        'rejected: red ticket, the authority reason, the refund and the resubmit action',
        (tester) async {
      await open(
        tester,
        _detail(
          RequestStatus.rejected,
          rejectionReason: 'اختلاف في تاريخ الميلاد',
          refundedCents: 6000,
        ),
      );
      expect(find.text('عبدالرحمن فيصل · حجز طيران'), findsOneWidget);
      expect(find.text('سبب الرفض من الجهة'), findsOneWidget);
      expect(find.text('اختلاف في تاريخ الميلاد'), findsOneWidget);
      expect(find.textContaining('60.00'), findsOneWidget);
      expect(find.text('تواصل مع الدعم'), findsOneWidget);
      expect(find.text('تصحيح وإعادة التقديم'), findsOneWidget);
    });

    testWidgets('rejected without a reason says so', (tester) async {
      await open(tester, _detail(RequestStatus.rejected));
      expect(find.textContaining('لم تُرسل الجهة سببًا'), findsOneWidget);
    });

    testWidgets(
        'cancelled: who, when, why, the refund and a new request with the same data',
        (tester) async {
      await open(
        tester,
        _detail(
          RequestStatus.cancelled,
          cancellation: RequestCancellationInfo(
            cancelledBy: 'وليد ناصر (موظف)',
            cancelledAt: DateTime(2026, 10, 10, 14, 20),
            reason: 'العميل غيّر موعد السفر',
          ),
          refundedCents: 8500,
        ),
      );
      expect(find.text('ألغاه: وليد ناصر (موظف) · ١٠ أكتوبر 14:20'),
          findsOneWidget);
      expect(find.text('السبب: العميل غيّر موعد السفر'), findsOneWidget);
      expect(find.text('أُعيد 85.00 USD إلى رصيدك.', findRichText: true),
          findsNothing);
      expect(find.textContaining('85.00'), findsOneWidget);
      expect(find.text('طلب جديد بنفس البيانات'), findsOneWidget);
    });

    testWidgets(
        'expired by the automatic cancellation shows the lapsed-deadline card',
        (tester) async {
      await open(
        tester,
        _detail(
          RequestStatus.cancelled,
          cancellation: const RequestCancellationInfo(expiredByDeadline: true),
          refundedCents: 6000,
        ),
      );
      expect(find.text('انتهت المهلة'), findsOneWidget);
      expect(find.textContaining('انتهت مهلة ٧٢ ساعة'), findsOneWidget);
      expect(find.textContaining('أُعيد المبلغ المحجوز'), findsOneWidget);
      expect(find.text('ألغاه:'), findsNothing);
    });
  });
}
