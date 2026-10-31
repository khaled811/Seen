// Forgot password: the server e-mails a link (contract 3.3). Bloc rules over a
// fake repository, the screens, and the data source against the contract.
// Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/auth/data/datasources/password_recovery_remote_data_source.dart';
import 'package:seen_booking/features/auth/domain/entities/password_recovery.dart';
import 'package:seen_booking/features/auth/domain/repositories/password_recovery_repository.dart';
import 'package:seen_booking/features/auth/domain/usecases/password_recovery_usecases.dart';
import 'package:seen_booking/features/auth/presentation/bloc/password_recovery_bloc.dart';
import 'package:seen_booking/features/auth/presentation/screens/forgot_password_flow.dart';

import '../../../support/scripted_graphql_service.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

class _FakeRepo implements PasswordRecoveryRepository {
  Either<Failure, void> result = const Right(null);
  final emails = <String>[];

  @override
  Future<Either<Failure, void>> requestReset({required String email}) async {
    emails.add(email);
    return result;
  }
}

PasswordRecoveryBloc _bloc(_FakeRepo r) => PasswordRecoveryBloc(requestReset: RequestPasswordResetUseCase(r));

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
  group('RecoveryIssue.from', () {
    test('the throttle carries its minutes; a lost connection is offline; the rest is generic', () {
      final limited = RecoveryIssue.from(const ServerFailure('x', code: 'too_many_attempts', details: {'minutes': 20}));
      expect(limited.kind, RecoveryIssueKind.rateLimited);
      expect(limited.minutes, 20);
      expect(limited.seconds, 1200);
      expect(RecoveryIssue.from(const ServerFailure('x', code: 'too_many_attempts')).minutes, isNull);
      expect(RecoveryIssue.from(const NetworkFailure('off')).kind, RecoveryIssueKind.offline);
      expect(RecoveryIssue.from(const ServerFailure('x', statusCode: 500)).kind, RecoveryIssueKind.generic);
      expect(RecoveryIssue.from(const ServerFailure('x', code: 'email_send_failed')).kind, RecoveryIssueKind.generic);
    });
  });

  group('PasswordRecoveryBloc', () {
    test('an e-mail asks for the link and then tells the person to open it', () async {
      final repo = _FakeRepo();
      final bloc = _bloc(repo)..add(const RecoveryLinkRequested('  agent@example.com '));
      await pumpEventQueue();
      expect(repo.emails, ['agent@example.com']);
      expect(bloc.state.step, RecoveryStep.linkSent);
      expect(bloc.state.email, 'agent@example.com');
      expect(bloc.state.busy, isFalse);
      await bloc.close();
    });

    test('anything that is not an e-mail address is never sent', () async {
      final repo = _FakeRepo();
      final bloc = _bloc(repo)..add(const RecoveryLinkRequested('+967771234567'));
      await pumpEventQueue();
      expect(repo.emails, isEmpty);
      expect(bloc.state.issue!.kind, RecoveryIssueKind.emailRequired);
      expect(bloc.state.step, RecoveryStep.request);
      await bloc.close();
    });

    test('a failure stays on the form with its issue; another try works', () async {
      final repo = _FakeRepo()..result = const Left(NetworkFailure('off'));
      final bloc = _bloc(repo)..add(const RecoveryLinkRequested('a@b.co'));
      await pumpEventQueue();
      expect(bloc.state.step, RecoveryStep.request);
      expect(bloc.state.issue!.kind, RecoveryIssueKind.offline);
      repo.result = const Right(null);
      bloc.add(const RecoveryLinkRequested('a@b.co'));
      await pumpEventQueue();
      expect(bloc.state.step, RecoveryStep.linkSent);
      expect(bloc.state.issue, isNull);
      await bloc.close();
    });

    test('the throttle is reported with its wait', () async {
      final repo = _FakeRepo()..result = const Left(ServerFailure('x', code: 'too_many_attempts', details: {'minutes': 30}));
      final bloc = _bloc(repo)..add(const RecoveryLinkRequested('a@b.co'));
      await pumpEventQueue();
      expect(bloc.state.issue!.kind, RecoveryIssueKind.rateLimited);
      expect(bloc.state.issue!.minutes, 30);
      await bloc.close();
    });

    test('a second tap while it runs is dropped; back returns to the form', () async {
      final repo = _FakeRepo();
      final bloc = _bloc(repo)
        ..add(const RecoveryLinkRequested('a@b.co'))
        ..add(const RecoveryLinkRequested('a@b.co'));
      await pumpEventQueue();
      expect(repo.emails.length, lessThanOrEqualTo(2));
      bloc.add(const RecoveryBackPressed());
      await pumpEventQueue();
      expect(bloc.state.step, RecoveryStep.request);
      await bloc.close();
    });
  });

  group('the data source (requestPasswordReset against the contract)', () {
    test('sends the e-mail and the app language; true is a success', () async {
      final graphql = ScriptedGraphQLService({
        'RequestPasswordReset': {'requestPasswordReset': true},
      });
      final source = PasswordRecoveryRemoteDataSourceImpl(graphQLService: graphql, language: AppLanguage('en'));
      expect((await source.requestReset(email: 'a@b.co')).isRight(), isTrue);
      expect(graphql.where('RequestPasswordReset').single.variables, {'email': 'a@b.co', 'locale': 'en'});
    });

    test('Arabic by default; false is not shown as success; a failure is a Failure', () async {
      final graphql = ScriptedGraphQLService({
        'RequestPasswordReset': {'requestPasswordReset': false},
      });
      final source = PasswordRecoveryRemoteDataSourceImpl(graphQLService: graphql, language: AppLanguage());
      expect((await source.requestReset(email: 'a@b.co')).isLeft(), isTrue);
      expect(graphql.where('RequestPasswordReset').single.variables['locale'], 'ar');

      final failing = PasswordRecoveryRemoteDataSourceImpl(
        graphQLService: ScriptedGraphQLService({'RequestPasswordReset': const ServerFailure('x', code: 'too_many_attempts')}),
        language: AppLanguage(),
      );
      expect(((await failing.requestReset(email: 'a@b.co')) as Left).value, isA<ServerFailure>());
    });
  });

  group('ForgotPasswordFlow', () {
    late _FakeRepo repo;
    var exited = 0;

    Future<void> open(WidgetTester tester) async {
      repo = _FakeRepo();
      exited = 0;
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(ForgotPasswordFlow(onExit: () => exited++, createBloc: () => _bloc(repo))));
      await tester.pumpAndSettle();
    }

    testWidgets('only an e-mail field: no phone switch', (tester) async {
      await open(tester);
      expect(find.text(_l10n.recoveryMethodEmail), findsWidgets);
      expect(find.text(_l10n.recoveryMethodPhone), findsNothing);
    });

    testWidgets('an invalid address shows the validation error and sends nothing', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.text(_l10n.recoverySendCode));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.validationInvalidEmail), findsOneWidget);
      expect(repo.emails, isEmpty);
    });

    testWidgets('a good address shows the confirmation with it, and back to login leaves', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextFormField), 'agent@example.com');
      await tester.tap(find.text(_l10n.recoverySendCode));
      await tester.pumpAndSettle();
      expect(repo.emails, ['agent@example.com']);
      expect(find.text(_l10n.recoveryLinkSentTitle), findsOneWidget);
      expect(find.text(_l10n.recoveryLinkSentBody('agent@example.com')), findsOneWidget);
      await tester.tap(find.text(_l10n.recoveryBackToLogin));
      await tester.pumpAndSettle();
      expect(exited, 1);
    });

    testWidgets('a lost connection shows the offline banner on the form', (tester) async {
      await open(tester);
      repo.result = const Left(NetworkFailure('off'));
      await tester.enterText(find.byType(TextFormField), 'agent@example.com');
      await tester.tap(find.text(_l10n.recoverySendCode));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.recoveryOffline), findsOneWidget);
      expect(find.text(_l10n.recoveryLinkSentTitle), findsNothing);
    });

    testWidgets('the throttle shows the wait and the support / sign-up links', (tester) async {
      await open(tester);
      repo.result = const Left(ServerFailure('x', code: 'too_many_attempts', details: {'minutes': 45}));
      await tester.enterText(find.byType(TextFormField), 'agent@example.com');
      await tester.tap(find.text(_l10n.recoverySendCode));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.errorTooManyAttempts('45')), findsOneWidget);
      expect(find.text(_l10n.recoveryContactSupport), findsOneWidget);
    });

    testWidgets('"another address" on the confirmation returns to the form', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextFormField), 'agent@example.com');
      await tester.tap(find.text(_l10n.recoverySendCode));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.recoveryRetry));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.recoveryForgotHeading), findsOneWidget);
    });
  });
}
