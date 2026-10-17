// Cancel request (Figma REQ-10 / 10b): the reason sheet with the refund note,
// the chosen reason reaching the repository, and the "can't cancel now" dialog
// when the server refuses. Arabic / RTL.

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
import 'package:seen_booking/features/requests/domain/entities/cancel_reason.dart';
import 'package:seen_booking/features/requests/domain/entities/request_detail.dart';
import 'package:seen_booking/features/requests/domain/entities/request_summary.dart';
import 'package:seen_booking/features/requests/domain/repositories/requests_repository.dart';
import 'package:seen_booking/features/requests/domain/usecases/cancel_request_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_request_detail_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_requests_usecase.dart';
import 'package:seen_booking/features/requests/domain/usecases/remind_approver_usecase.dart';
import 'package:seen_booking/features/requests/presentation/bloc/approver_reminder_cubit.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_bloc.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_event.dart';
import 'package:seen_booking/features/requests/presentation/bloc/requests_state.dart';
import 'package:seen_booking/features/requests/presentation/screens/request_detail_screen.dart';

RequestDetail _detail(RequestStatus status) => RequestDetail(
      id: 'r1',
      referenceId: 'SB-20484',
      serviceName: 'حجز طيران',
      status: status,
      totalPriceCents: 124000,
      submittedAt: DateTime(2026, 10, 1),
      travelers: const [],
      timeline: const [],
    );

class _Repo implements RequestsRepository {
  _Repo({this.refuse = false});

  final bool refuse;
  CancelReason? lastReason;
  int cancels = 0;

  @override
  Future<Either<Failure, List<RequestSummary>>> getRequests() async =>
      const Right([]);

  @override
  Future<Either<Failure, RequestDetail>> getRequestDetail(
          String requestId) async =>
      Right(_detail(RequestStatus.pendingAgentApproval));

  @override
  Future<Either<Failure, RequestDetail>> cancelRequest(String requestId,
      {CancelReason? reason}) async {
    cancels++;
    lastReason = reason;
    if (refuse) {
      return const Left(ServerFailure('no', code: 'NOT_CANCELLABLE'));
    }
    return Right(_detail(RequestStatus.cancelled));
  }

  @override
  Future<Either<Failure, void>> remindApprover(String requestId) async =>
      const Right(null);
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

  Future<(_Repo, RequestsBloc)> open(WidgetTester tester,
      {bool refuse = false}) async {
    final repo = _Repo(refuse: refuse);
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = RequestsBloc(
      getRequestsUseCase: GetRequestsUseCase(repo),
      getRequestDetailUseCase: GetRequestDetailUseCase(repo),
      cancelRequestUseCase: CancelRequestUseCase(repo),
    )..add(const RequestsLoadRequested());
    addTearDown(() => bloc.close().ignore());
    await settle(tester);
    bloc.add(const RequestDetailRequested('r1'));
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
          createReminderCubit: () =>
              ApproverReminderCubit(remindApprover: RemindApproverUseCase(repo)),
        ),
      ),
    ));
    await settle(tester);
    return (repo, bloc);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('إلغاء الطلب'));
    await settle(tester);
  }

  testWidgets('the sheet lists the reasons and the refund note',
      (tester) async {
    await open(tester);
    await openSheet(tester);
    expect(find.text('SB-20484 · حجز طيران'), findsOneWidget);
    for (final label in const [
      'العميل ألغى السفر',
      'خطأ في البيانات',
      'تأخر التنفيذ',
      'سبب آخر',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('1,240.00'), findsOneWidget);
    expect(find.text('تراجع'), findsOneWidget);
    expect(find.text('تأكيد الإلغاء'), findsOneWidget);
  });

  testWidgets('going back cancels nothing', (tester) async {
    final (repo, _) = await open(tester);
    await openSheet(tester);
    await tester.tap(find.text('تراجع'));
    await settle(tester);
    expect(repo.cancels, 0);
    expect(find.text('تأكيد الإلغاء'), findsNothing);
  });

  testWidgets('the chosen reason is sent with the cancellation',
      (tester) async {
    final (repo, bloc) = await open(tester);
    await openSheet(tester);
    await tester.tap(find.text('تأخر التنفيذ'));
    await tester.pump();
    await tester.tap(find.text('تأكيد الإلغاء'));
    await settle(tester);
    expect(repo.cancels, 1);
    expect(repo.lastReason, CancelReason.delayed);
    expect((bloc.state as RequestsLoaded).cancelStatus,
        RequestCancelStatus.success);
  });

  testWidgets('the first reason is preselected', (tester) async {
    final (repo, _) = await open(tester);
    await openSheet(tester);
    await tester.tap(find.text('تأكيد الإلغاء'));
    await settle(tester);
    expect(repo.lastReason, CancelReason.customerCancelled);
  });

  testWidgets('a refusal shows the not-cancellable dialog', (tester) async {
    final (_, bloc) = await open(tester, refuse: true);
    await openSheet(tester);
    await tester.tap(find.text('تأكيد الإلغاء'));
    await settle(tester);
    expect((bloc.state as RequestsLoaded).cancelStatus,
        RequestCancelStatus.notCancellable);
    expect(find.text('لا يمكن إلغاء الطلب الآن'), findsOneWidget);
    expect(find.textContaining('الطلب لدى الجهة المختصة'), findsOneWidget);
    expect(find.text('تواصل مع الدعم'), findsOneWidget);
    await tester.tap(find.text('حسنًا'));
    await settle(tester);
    expect(find.text('لا يمكن إلغاء الطلب الآن'), findsNothing);
  });
}
