// Agency registration after the form (Figma AUTH-05 … AUTH-07): bloc rules over
// a fake repository, and the three screens end to end. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/auth/domain/entities/agency_registration.dart';
import 'package:seen_booking/features/auth/domain/repositories/agency_registration_repository.dart';
import 'package:seen_booking/features/auth/domain/usecases/agency_registration_usecases.dart';
import 'package:seen_booking/features/auth/presentation/bloc/agency_registration_bloc.dart';
import 'package:seen_booking/features/auth/presentation/screens/agency_registration_flow.dart';

const _draft = AgencyRegistrationDraft(
  agencyName: 'وكالة النور',
  managerName: 'أحمد محمد',
  phone: '+967771234567',
  email: 'agency@example.com',
  city: 'صنعاء',
  licenseNumber: 'CR-1',
);

const _challenge = RegistrationChallenge(
  challengeToken: 'c1',
  maskedPhone: '+967 77 ••• 0700',
  resendCooldownSeconds: 45,
);

class _FakeRepo implements AgencyRegistrationRepository {
  Either<Failure, RegistrationChallenge> startResult = const Right(_challenge);
  Either<Failure, String> verifyResult = const Right('v1');
  Either<Failure, void> completeResult = const Right(null);
  int starts = 0;
  int resends = 0;
  int completes = 0;
  String? lastPassword;
  RegistrationConsent? lastConsent;

  @override
  Future<Either<Failure, RegistrationChallenge>> start({
    required AgencyRegistrationDraft draft,
    required String password,
  }) async {
    starts++;
    lastPassword = password;
    return startResult;
  }

  @override
  Future<Either<Failure, RegistrationChallenge>> resendCode({required String challengeToken}) async {
    resends++;
    return const Right(_challenge);
  }

  @override
  Future<Either<Failure, String>> verifyPhone({required String challengeToken, required String code}) async =>
      verifyResult;

  @override
  Future<Either<Failure, void>> complete({
    required String verificationToken,
    required RegistrationConsent consent,
  }) async {
    completes++;
    lastConsent = consent;
    return completeResult;
  }
}

AgencyRegistrationBloc _bloc(_FakeRepo r) => AgencyRegistrationBloc(
      draft: _draft,
      start: StartAgencyRegistrationUseCase(r),
      resendCode: ResendRegistrationCodeUseCase(r),
      verifyPhone: VerifyRegistrationPhoneUseCase(r),
      complete: CompleteAgencyRegistrationUseCase(r),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('RegistrationIssue.from', () {
    test('maps backend codes and their details', () {
      expect(RegistrationIssue.from(const NetworkFailure('x')).kind, RegistrationIssueKind.offline);
      expect(
        RegistrationIssue.from(const ServerFailure('x', code: RegistrationIssue.phoneTakenCode)).kind,
        RegistrationIssueKind.phoneTaken,
      );
      final wrong = RegistrationIssue.from(
        const ServerFailure('x', code: RegistrationIssue.wrongCodeCode, details: {'attemptsLeft': 2}),
      );
      expect((wrong.kind, wrong.attemptsLeft), (RegistrationIssueKind.wrongCode, 2));
      expect(RegistrationIssue.from(const ServerFailure('boom')).kind, RegistrationIssueKind.generic);
    });
  });

  group('AgencyRegistrationBloc', () {
    test('password → otp → terms → done', () async {
      final repo = _FakeRepo();
      final bloc = _bloc(repo);
      addTearDown(bloc.close);

      bloc.add(const RegistrationPasswordSubmitted('Abcdef12'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.otp);
      expect(repo.lastPassword, 'Abcdef12');
      expect(bloc.state.codesSent, 1);

      bloc.add(const RegistrationCodeSubmitted('123456'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.terms);
      expect(bloc.state.verificationToken, 'v1');

      bloc.add(const RegistrationConsentSubmitted(RegistrationConsent(acceptedTerms: true, acceptedPrivacy: true)));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.done);
      expect(repo.lastConsent?.marketing, false);
    });

    test('consent without terms or privacy is ignored', () async {
      final repo = _FakeRepo();
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const RegistrationPasswordSubmitted('Abcdef12'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.otp);
      bloc.add(const RegistrationCodeSubmitted('123456'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.terms);

      bloc.add(const RegistrationConsentSubmitted(RegistrationConsent(acceptedTerms: true, acceptedPrivacy: false)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.completes, 0);
      expect(bloc.state.step, RegistrationStep.terms);
    });

    test('a wrong code keeps the otp step with the attempts left; resend bumps codesSent', () async {
      final repo = _FakeRepo()
        ..verifyResult = const Left(
          ServerFailure('x', code: RegistrationIssue.wrongCodeCode, details: {'attemptsLeft': 2}),
        );
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const RegistrationPasswordSubmitted('Abcdef12'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.otp);

      bloc.add(const RegistrationCodeSubmitted('111111'));
      final wrong = await bloc.stream.firstWhere((s) => s.issue != null);
      expect(wrong.step, RegistrationStep.otp);
      expect(wrong.issue!.attemptsLeft, 2);

      bloc.add(const RegistrationResendRequested());
      final resent = await bloc.stream.firstWhere((s) => s.codesSent == 2);
      expect(resent.issue, isNull);
      expect(repo.resends, 1);
    });

    test('back from otp and from terms returns to the password step', () async {
      final repo = _FakeRepo();
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const RegistrationPasswordSubmitted('Abcdef12'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.otp);
      bloc.add(const RegistrationBackPressed());
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.password);

      bloc.add(const RegistrationPasswordSubmitted('Abcdef12'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.otp);
      bloc.add(const RegistrationCodeSubmitted('123456'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.terms);
      bloc.add(const RegistrationBackPressed());
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.password);
    });
  });

  group('AgencyRegistrationFlow', () {
    late _FakeRepo repo;

    Future<void> open(
      WidgetTester tester, {
      VoidCallback? onExit,
      VoidCallback? onCompleted,
      VoidCallback? onSignIn,
    }) async {
      repo = _FakeRepo();
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
        home: AgencyRegistrationFlow(
          draft: _draft,
          onExit: onExit ?? () {},
          onCompleted: onCompleted ?? () {},
          onSignIn: onSignIn,
          createBloc: () => _bloc(repo),
        ),
      ));
      await tester.pump();
    }

    Future<void> toOtp(WidgetTester tester) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Seen@2026');
      await tester.pump();
      await tester.enterText(fields.at(1), 'Seen@2026');
      await tester.pump();
      await tester.tap(find.text('متابعة'));
      await _settle(tester);
    }

    testWidgets('continue stays disabled until the rules pass and the passwords match', (tester) async {
      await open(tester);
      expect(find.text('الخطوة ٢ من ٤'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'abc');
      await tester.pump();
      await tester.enterText(fields.at(1), 'abc');
      await tester.pump();
      await tester.tap(find.text('متابعة'));
      await _settle(tester);
      expect(repo.starts, 0);

      await tester.enterText(fields.at(0), 'Seen@2026');
      await tester.pump();
      await tester.enterText(fields.at(1), 'Seen@2027');
      await tester.pump();
      expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
      expect(find.text('قوية جدًا'), findsOneWidget);
    });

    testWidgets('the whole happy path ends on the completed callback', (tester) async {
      var completed = 0;
      await open(tester, onCompleted: () => completed++);

      await toOtp(tester);
      expect(repo.lastPassword, 'Seen@2026');
      expect(find.text('تحقق من رقم جوالك'), findsOneWidget);
      expect(find.text('الخطوة ٣ من ٤'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '123456');
      await _settle(tester);
      expect(find.text('قبل إنشاء الحساب'), findsOneWidget);
      expect(find.text('الخطوة ٤ من ٤'), findsOneWidget);

      // Without both mandatory consents nothing is sent.
      await tester.tap(find.text('إنشاء الحساب'));
      await _settle(tester);
      expect(repo.completes, 0);

      await tester.tap(find.text('أوافق على الشروط والأحكام'));
      await tester.pump();
      await tester.tap(find.text('أوافق على سياسة الخصوصية'));
      await tester.pump();
      await tester.tap(find.text('إنشاء الحساب'));
      await _settle(tester);
      expect(repo.completes, 1);
      expect(repo.lastConsent?.marketing, false);
      expect(completed, 1);
    });

    testWidgets('a phone linked to another account shows the red banner with a sign-in action', (tester) async {
      var signIns = 0;
      await open(tester, onSignIn: () => signIns++);
      repo.verifyResult = const Left(ServerFailure('x', code: RegistrationIssue.phoneTakenCode));

      await toOtp(tester);
      await tester.enterText(find.byType(TextField), '123456');
      await _settle(tester);
      expect(find.text('هذا الرقم مرتبط بحساب آخر. سجّل الدخول أو استعد كلمة المرور.'), findsOneWidget);

      await tester.tap(find.text('دخول'));
      expect(signIns, 1);
    });

    testWidgets('system back steps back inside the flow and leaves it from the first step', (tester) async {
      var exited = 0;
      await open(tester, onExit: () => exited++);
      await toOtp(tester);
      expect(find.text('تحقق من رقم جوالك'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('أنشئ كلمة مرور لحسابك'), findsOneWidget);
      expect(exited, 0);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exited, 1);
    });
  });
}
