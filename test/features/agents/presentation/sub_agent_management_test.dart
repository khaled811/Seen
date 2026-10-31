// Add sub-agent (Figma AGT-01 / 01b): issue mapping against the contract's error
// codes, the bloc over a fake repository, and the screen. Arabic / RTL.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/agents/domain/entities/new_sub_agent.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent_profile.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent_request_summary.dart';
import 'package:seen_booking/features/agents/domain/repositories/agents_repository.dart';
import 'package:seen_booking/features/agents/domain/usecases/sub_agent_management_usecases.dart';
import 'package:seen_booking/features/agents/presentation/bloc/sub_agent_management_bloc.dart';
import 'package:seen_booking/features/agents/presentation/screens/add_sub_agent_screen.dart';

class _Repo implements AgentsRepository {
  /// Holds `createSubAgent` open until completed (to overlap two submissions).
  Completer<void>? gate;
  Either<Failure, SubAgent>? createResult;
  NewSubAgent? lastNew;
  int creates = 0;

  @override
  Future<Either<Failure, SubAgent>> createSubAgent(NewSubAgent n) async {
    creates++;
    lastNew = n;
    await gate?.future;
    return createResult ??
        Right(SubAgent(id: 'n', name: n.agencyName, code: '', balanceCents: 0, isActive: false, invitePending: true));
  }

  @override
  Future<Either<Failure, SubAgentProfile>> getSubAgentProfile(String subAgentId) async =>
      const Right(SubAgentProfile(agent: SubAgent(id: 'x', name: 'x', code: 'x', balanceCents: 0, isActive: true)));

  @override
  Future<Either<Failure, void>> setSubAgentActive({required String subAgentId, required bool active}) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<SubAgent>>> getSubAgents() async => const Right([]);

  @override
  Future<Either<Failure, List<SubAgentRequestSummary>>> getPendingApprovalRequests() async => const Right([]);

  @override
  Future<Either<Failure, void>> approveRequest(String requestId) async => const Right(null);

  @override
  Future<Either<Failure, void>> rejectRequest(String requestId, {required String reason}) async => const Right(null);

  @override
  Future<Either<Failure, void>> fundSubAgentWallet({
    required String subAgentId,
    required int amountCents,
    required String idempotencyKey,
    String? note,
  }) async =>
      const Right(null);
}

const _newAgent = NewSubAgent(
  agencyName: 'مكتب الريان',
  managerName: 'وليد',
  email: 'walid@example.com',
  password: 'Abcdef12-long-pw',
);

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

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('SubAgentIssue.from maps the contract codes', () {
    SubAgentIssueKind kind(Failure f) => SubAgentIssue.from(f).kind;
    expect(kind(const NetworkFailure('x')), SubAgentIssueKind.offline);
    expect(kind(const ServerFailure('x', code: 'owner_email_taken')), SubAgentIssueKind.emailTaken);
    expect(kind(const ServerFailure('x', code: 'password_weak')), SubAgentIssueKind.weakPassword);
    expect(kind(const ServerFailure('x', code: 'sub_agent_depth')), SubAgentIssueKind.notAllowed);
    expect(kind(const ForbiddenFailure()), SubAgentIssueKind.notAllowed);
    expect(kind(const ServerFailure('x', code: 'funds_exceed_balance')), SubAgentIssueKind.amountExceedsBalance);
    expect(kind(const ServerFailure('boom')), SubAgentIssueKind.generic);
  });

  group('AddSubAgentBloc', () {
    test('success, then reset', () async {
      final repo = _Repo();
      final bloc = AddSubAgentBloc(createSubAgent: CreateSubAgentUseCase(repo));
      addTearDown(bloc.close);
      bloc.add(const AddSubAgentSubmitted(_newAgent));
      final s = await bloc.stream.firstWhere((s) => s.created != null);
      expect(s.created!.invitePending, true);
      bloc.add(const AddSubAgentReset());
      await bloc.stream.firstWhere((s) => s.created == null);
    });

    test('a taken e-mail is reported and dismissible', () async {
      final repo = _Repo()..createResult = const Left(ServerFailure('x', code: 'owner_email_taken'));
      final bloc = AddSubAgentBloc(createSubAgent: CreateSubAgentUseCase(repo));
      addTearDown(bloc.close);
      bloc.add(const AddSubAgentSubmitted(_newAgent));
      final s = await bloc.stream.firstWhere((s) => s.issue != null);
      expect(s.issue!.kind, SubAgentIssueKind.emailTaken);
      bloc.add(const AddSubAgentIssueDismissed());
      await bloc.stream.firstWhere((s) => s.issue == null);
    });

    test('a double tap creates one agency (droppable)', () async {
      final repo = _Repo()..gate = Completer<void>();
      final bloc = AddSubAgentBloc(createSubAgent: CreateSubAgentUseCase(repo));
      addTearDown(bloc.close);
      bloc
        ..add(const AddSubAgentSubmitted(_newAgent))
        ..add(const AddSubAgentSubmitted(_newAgent));
      await bloc.stream.firstWhere((s) => s.submitting);
      await pumpEventQueue();
      repo.gate!.complete();
      await bloc.stream.firstWhere((s) => s.created != null);
      expect(repo.creates, 1);
    });
  });

  group('AddSubAgentScreen', () {
    late _Repo repo;

    Future<void> open(WidgetTester tester) async {
      repo = _Repo();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
            builder: (_) => AddSubAgentScreen(
              createBloc: () => AddSubAgentBloc(createSubAgent: CreateSubAgentUseCase(repo)),
            ),
          )),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, {String password = 'Abcdef12-long-pw'}) async {
      final f = find.byType(TextFormField);
      await tester.enterText(f.at(0), 'مكتب الريان للسفر');
      await tester.pump();
      await tester.enterText(f.at(1), 'وليد ناصر الريان');
      await tester.pump();
      await tester.enterText(f.at(2), 'walid@example.com');
      await tester.pump();
      await tester.enterText(f.at(3), password);
      await tester.pump();
    }

    testWidgets('an empty form shows the required errors and sends nothing', (tester) async {
      await open(tester);
      await tester.tap(find.text('إضافة الوكيل'));
      await tester.pump();
      expect(find.text('هذا الحقل مطلوب.'), findsWidgets);
      expect(repo.creates, 0);
    });

    testWidgets('a password under 12 characters is refused before anything is sent', (tester) async {
      await open(tester);
      await fill(tester, password: 'Short-1');
      await tester.tap(find.text('إضافة الوكيل'));
      await tester.pump();
      expect(find.text('استخدم ١٢ حرفًا على الأقل.'), findsOneWidget);
      expect(repo.creates, 0);
    });

    testWidgets('a valid form sends the contract fields and shows the success page', (tester) async {
      await open(tester);
      await fill(tester);
      await tester.tap(find.text('إضافة الوكيل'));
      await settle(tester);
      expect(repo.lastNew!.agencyName, 'مكتب الريان للسفر');
      expect(repo.lastNew!.managerName, 'وليد ناصر الريان');
      expect(repo.lastNew!.email, 'walid@example.com');
      expect(repo.lastNew!.password, 'Abcdef12-long-pw');
      expect(find.text('أُضيف الوكيل'), findsOneWidget);
      expect(find.text('قيد التفعيل'), findsOneWidget);

      await tester.tap(find.text('إضافة آخر'));
      await settle(tester);
      expect(find.text('إضافة الوكيل'), findsOneWidget);
      expect(tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text, isEmpty);
    });

    testWidgets('a taken e-mail shows the red message under the field', (tester) async {
      await open(tester);
      repo.createResult = const Left(ServerFailure('x', code: 'owner_email_taken'));
      await fill(tester);
      await tester.tap(find.text('إضافة الوكيل'));
      await settle(tester);
      expect(find.text('هذا البريد مسجّل لوكيل آخر. استخدم بريدًا مختلفًا.'), findsOneWidget);
      expect(find.text('أُضيف الوكيل'), findsNothing);
    });

    testWidgets('a password the server calls weak shows its own message', (tester) async {
      await open(tester);
      repo.createResult = const Left(ServerFailure('x', code: 'password_weak'));
      await fill(tester);
      await tester.tap(find.text('إضافة الوكيل'));
      await settle(tester);
      expect(find.textContaining('كلمة المرور مرفوضة'), findsOneWidget);
    });

    testWidgets('back to the agents leaves with true so the list reloads', (tester) async {
      await open(tester);
      await fill(tester);
      await tester.tap(find.text('إضافة الوكيل'));
      await settle(tester);
      await tester.tap(find.text('العودة إلى الوكلاء'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  });
}
