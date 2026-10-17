// Login failure states (Figma AUTH-11), registration field errors (AUTH-08) and
// the sign-out confirmation with pending uploads (AUTH-14). Arabic / RTL.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/network/auth_session_controller.dart';
import 'package:seen_booking/core/presentation/foundation/seen_icons.dart';
import 'package:seen_booking/core/services/pending_uploads.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/auth/domain/entities/agency_registration.dart';
import 'package:seen_booking/features/auth/domain/entities/auth_attempt_result.dart';
import 'package:seen_booking/features/auth/domain/entities/user_session.dart';
import 'package:seen_booking/features/auth/domain/repositories/agency_registration_repository.dart';
import 'package:seen_booking/features/auth/domain/repositories/auth_repository.dart';
import 'package:seen_booking/features/auth/domain/usecases/agency_registration_usecases.dart';
import 'package:seen_booking/features/auth/domain/usecases/get_persisted_session_usecase.dart';
import 'package:seen_booking/features/auth/domain/usecases/login_usecase.dart';
import 'package:seen_booking/features/auth/domain/usecases/logout_usecase.dart';
import 'package:seen_booking/features/auth/domain/usecases/resend_otp_usecase.dart';
import 'package:seen_booking/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:seen_booking/features/auth/presentation/bloc/agency_registration_bloc.dart';
import 'package:seen_booking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:seen_booking/features/auth/presentation/bloc/auth_event.dart';
import 'package:seen_booking/features/auth/presentation/bloc/auth_state.dart';
import 'package:seen_booking/features/auth/presentation/screens/agency_registration_flow.dart';
import 'package:seen_booking/features/auth/presentation/screens/create_agency_account_screen.dart';
import 'package:seen_booking/features/auth/presentation/screens/login_screen.dart';
import 'package:seen_booking/features/auth/presentation/widgets/logout_confirm_dialog.dart';
import 'package:seen_booking/features/requests/domain/entities/missing_document.dart';
import 'package:seen_booking/features/requests/domain/repositories/missing_document_repository.dart';
import 'package:seen_booking/features/requests/domain/services/document_picker.dart';
import 'package:seen_booking/features/requests/domain/usecases/missing_document_usecases.dart';
import 'package:seen_booking/features/requests/presentation/bloc/missing_document_bloc.dart';

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

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _AuthRepo implements AuthRepository {
  Either<Failure, AuthAttemptResult> loginResult = const Left(ServerFailure('x'));

  @override
  Future<Either<Failure, AuthAttemptResult>> login({required String identifier, required String password}) async =>
      loginResult;

  @override
  Future<Either<Failure, UserSession>> verifyOtp({required String challengeToken, required String code}) async =>
      const Left(ServerFailure('x'));

  @override
  Future<Either<Failure, AuthOtpChallenge>> resendOtp({required String challengeToken}) async =>
      const Left(ServerFailure('x'));

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Future<UserSession?> getPersistedSession() async => null;
}

AuthBloc _authBloc(_AuthRepo repo) => AuthBloc(
      loginUseCase: LoginUseCase(repo),
      verifyOtpUseCase: VerifyOtpUseCase(repo),
      resendOtpUseCase: ResendOtpUseCase(repo),
      logoutUseCase: LogoutUseCase(repo),
      getPersistedSessionUseCase: GetPersistedSessionUseCase(repo),
      authSessionController: AuthSessionController(),
    );

ServerFailure _code(String code, [Map<String, Object?> details = const {}]) =>
    ServerFailure('x', code: code, details: details);

void main() {
  group('login failure mapping', () {
    test('the server codes become reasons, with attempts left and the lock time', () async {
      final repo = _AuthRepo();
      final bloc = _authBloc(repo);
      addTearDown(bloc.close);
      Future<AuthFailure> fail(Failure f) async {
        repo.loginResult = Left(f);
        bloc.add(const AuthLoginSubmitted(identifier: '+967771234567', password: 'pw'));
        return await bloc.stream.firstWhere((s) => s is AuthFailure) as AuthFailure;
      }

      var f = await fail(_code('INVALID_CREDENTIALS', {'attemptsLeft': 3}));
      expect((f.reason, f.attemptsLeft), (LoginFailureReason.invalidCredentials, 3));
      f = await fail(_code('ACCOUNT_PENDING_APPROVAL'));
      expect(f.reason, LoginFailureReason.pendingApproval);
      f = await fail(_code('ACCOUNT_SUSPENDED'));
      expect(f.reason, LoginFailureReason.suspended);
      f = await fail(_code('ACCOUNT_LOCKED', {'retryAfterSeconds': 892}));
      expect((f.reason, f.retryAfterSeconds), (LoginFailureReason.locked, 892));
      f = await fail(const ServerFailure('boom'));
      expect(f.reason, LoginFailureReason.generic);
      f = await fail(const NetworkFailure('offline'));
      expect(f.reason, LoginFailureReason.generic);
    });
  });

  group('LoginScreen failures (AUTH-11)', () {
    Future<_AuthRepo> open(WidgetTester tester) async {
      final repo = _AuthRepo();
      final bloc = _authBloc(repo);
      addTearDown(() => bloc.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(BlocProvider.value(value: bloc, child: _app(const LoginScreen())));
      await tester.pump();
      return repo;
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.enterText(find.byType(TextFormField).at(0), '771234567');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
      await tester.tap(find.text('دخول'));
      await _settle(tester);
    }

    // Leaves no timer behind: the screen's lock countdown must be cancelled.
    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }

    testWidgets('wrong credentials: both fields marked, attempts left, cleared on typing', (tester) async {
      final repo = await open(tester);
      repo.loginResult = Left(_code('INVALID_CREDENTIALS', {'attemptsLeft': 3}));
      await submit(tester);
      expect(find.text('رقم الجوال أو كلمة المرور غير صحيحة. تبقّت ٣ محاولات.'), findsOneWidget);
      expect(find.byIcon(SeenIcons.alert), findsNWidgets(2));
      await tester.enterText(find.byType(TextFormField).at(1), 'another');
      await tester.pump();
      expect(find.textContaining('غير صحيحة'), findsNothing);
      expect(find.byIcon(SeenIcons.alert), findsNothing);
      await close(tester);
    });

    testWidgets('without attempts left the message stands alone', (tester) async {
      final repo = await open(tester);
      repo.loginResult = Left(_code('INVALID_CREDENTIALS'));
      await submit(tester);
      expect(find.text('رقم الجوال أو كلمة المرور غير صحيحة.'), findsOneWidget);
      await close(tester);
    });

    testWidgets('pending approval and suspended show their banners with a support action', (tester) async {
      final repo = await open(tester);
      repo.loginResult = Left(_code('ACCOUNT_PENDING_APPROVAL'));
      await submit(tester);
      expect(find.text('الحساب قيد المراجعة. سنبلغك عند التفعيل خلال يوم عمل.'), findsOneWidget);
      expect(find.text('الدعم'), findsOneWidget);

      repo.loginResult = Left(_code('ACCOUNT_SUSPENDED'));
      await tester.tap(find.text('دخول'));
      await _settle(tester);
      expect(find.text('الحساب موقوف. تواصل مع جُباري لمعرفة السبب.'), findsOneWidget);
      expect(find.text('تواصل'), findsOneWidget);
      await close(tester);
    });

    testWidgets('locked: a live countdown, sign-in disabled until it ends', (tester) async {
      final repo = await open(tester);
      repo.loginResult = Left(_code('ACCOUNT_LOCKED', {'retryAfterSeconds': 3}));
      await submit(tester);
      expect(find.textContaining('حاول بعد 0:03'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('حاول بعد 0:02'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('قُفل الدخول'), findsNothing);
      await close(tester);
    });

    testWidgets('an unknown failure is just a message', (tester) async {
      final repo = await open(tester);
      repo.loginResult = const Left(ServerFailure('تعذّر الاتصال بالخادم'));
      await submit(tester);
      expect(find.text('تعذّر الاتصال بالخادم'), findsOneWidget);
      expect(find.byIcon(SeenIcons.alert), findsNothing);
      await close(tester);
    });
  });

  group('registration field errors (AUTH-08)', () {
    test('licence and e-mail conflicts are form-field issues, the phone one is not', () {
      final license = RegistrationIssue.from(const ServerFailure('x', code: RegistrationIssue.licenseTakenCode));
      final email = RegistrationIssue.from(const ServerFailure('x', code: RegistrationIssue.emailTakenCode));
      final phone = RegistrationIssue.from(const ServerFailure('x', code: RegistrationIssue.phoneTakenCode));
      expect((license.kind, license.isFormFieldConflict), (RegistrationIssueKind.licenseTaken, true));
      expect((email.kind, email.isFormFieldConflict), (RegistrationIssueKind.emailTaken, true));
      expect(phone.isFormFieldConflict, false);
    });

    Future<void> openForm(WidgetTester tester, {RegistrationIssueKind? conflict}) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(CreateAgencyAccountScreen(
        onBack: () {},
        onSubmitted: (_) {},
        conflict: conflict,
        initial: const AgencyRegistrationDraft(
          agencyName: 'جُباري',
          managerName: 'وليد',
          phone: '+967771234567',
          email: 'info@jubari.net',
          city: 'صنعاء',
          licenseNumber: 'TL-1183',
        ),
      )));
      await tester.pump();
    }

    testWidgets('a taken licence number is marked until it is edited', (tester) async {
      await openForm(tester, conflict: RegistrationIssueKind.licenseTaken);
      expect(find.text('رقم الترخيص مسجّل لوكالة أخرى. تواصل مع الدعم إن كان هذا خطأ.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(5), 'TL-2000');
      await tester.pump();
      expect(find.textContaining('مسجّل لوكالة أخرى'), findsNothing);
    });

    testWidgets('a taken e-mail is marked until it is edited', (tester) async {
      await openForm(tester, conflict: RegistrationIssueKind.emailTaken);
      expect(find.text('البريد مستخدم في حساب آخر.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(3), 'other@jubari.net');
      await tester.pump();
      expect(find.text('البريد مستخدم في حساب آخر.'), findsNothing);
    });

    testWidgets('a badly formed e-mail says so with an example', (tester) async {
      await openForm(tester);
      await tester.enterText(find.byType(TextFormField).at(3), 'info@jubari');
      await tester.tap(find.text('متابعة'));
      await tester.pump();
      expect(find.text('صيغة البريد غير صحيحة. مثال: name@agency.com'), findsOneWidget);
    });

    testWidgets('a field the agent filled in correctly gets the accepted mark', (tester) async {
      await openForm(tester);
      final before = find.byIcon(SeenIcons.check).evaluate().length;
      await tester.enterText(find.byType(TextFormField).at(0), 'وكالة النور');
      await tester.pump();
      expect(find.byIcon(SeenIcons.check), findsNWidgets(before + 1));
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.pump();
      expect(find.byIcon(SeenIcons.check), findsNWidgets(before));
    });

    testWidgets('the flow sends a licence conflict back to the form', (tester) async {
      final repo = _RegRepo()..startResult = Left(_code(RegistrationIssue.licenseTakenCode));
      final bloc = AgencyRegistrationBloc(
        draft: const AgencyRegistrationDraft(
          agencyName: 'a',
          managerName: 'b',
          phone: '+967771234567',
          email: 'a@b.co',
          city: 'c',
          licenseNumber: 'd',
        ),
        start: StartAgencyRegistrationUseCase(repo),
        resendCode: ResendRegistrationCodeUseCase(repo),
        verifyPhone: VerifyRegistrationPhoneUseCase(repo),
        complete: CompleteAgencyRegistrationUseCase(repo),
      );
      RegistrationIssueKind? sent;
      await tester.pumpWidget(_app(AgencyRegistrationFlow(
        draft: bloc.draft,
        onExit: () {},
        onCompleted: () {},
        onFieldConflict: (kind) => sent = kind,
        createBloc: () => bloc,
      )));
      bloc.add(const RegistrationPasswordSubmitted('Abcdef12'));
      await _settle(tester);
      expect(sent, RegistrationIssueKind.licenseTaken);
    });
  });

  group('sign-out confirmation (AUTH-14)', () {
    Future<bool?> ask(WidgetTester tester, {List<String> pending = const []}) async {
      bool? result;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showLogoutConfirmDialog(context, pendingReferences: pending),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('with nothing running it asks plainly', (tester) async {
      await ask(tester);
      expect(find.text('تسجيل الخروج؟'), findsOneWidget);
      expect(find.text('ستحتاج إلى تسجيل الدخول مرة أخرى للوصول إلى حسابك.'), findsOneWidget);
      expect(find.text('خروج'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
    });

    testWidgets('one unfinished upload is named, several are counted', (tester) async {
      await ask(tester, pending: ['SB-20487']);
      expect(find.textContaining('لديك رفع مستند لم يكتمل'), findsOneWidget);
      expect(find.textContaining('SB-20487'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      await ask(tester, pending: ['SB-1', 'SB-2']);
      expect(find.textContaining('٢ عمليات رفع لم تكتمل'), findsOneWidget);
    });

    testWidgets('exit confirms, cancel does not', (tester) async {
      bool? result;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showLogoutConfirmDialog(context),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(result, false);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('خروج'));
      await tester.pumpAndSettle();
      expect(result, true);
    });
  });

  group('PendingUploads', () {
    test('an upload counts from begin to end, by request reference', () {
      final pending = PendingUploads();
      expect(pending.isEmpty, true);
      final endA = pending.begin(requestId: 'r1', referenceId: 'SB-1');
      final endB = pending.begin(requestId: 'r2', referenceId: 'SB-2');
      expect(pending.references, ['SB-1', 'SB-2']);
      endA();
      expect(pending.references, ['SB-2']);
      endB();
      endB(); // ending twice is harmless
      expect(pending.isEmpty, true);
    });

    test('the upload bloc registers while it runs, even when it fails, and then lets go', () async {
      final repo = _UploadRepo();
      final pending = PendingUploads();
      final bloc = MissingDocumentBloc(
        getMissingDocument: GetMissingDocumentUseCase(repo),
        uploadDocument: UploadMissingDocumentUseCase(repo),
        pickDocument: PickDocumentUseCase(_Picker()),
        clock: () => DateTime(2026, 10, 15, 12),
        pendingUploads: pending,
      );
      addTearDown(bloc.close);
      bloc.add(const MissingDocumentStarted('r1'));
      await bloc.stream.firstWhere((s) => s.status == MissingDocumentStatus.ready);
      bloc.add(const MissingDocumentSourceChosen(DocumentSource.file));
      await bloc.stream.firstWhere((s) => s.picked != null);

      bloc.add(const MissingDocumentSubmitted());
      await repo.started.future;
      expect(pending.references, ['SB-20476']);
      repo.gate.complete(const Left(NetworkFailure('offline')));
      await bloc.stream.firstWhere((s) => !s.uploading && s.issue != null);
      expect(pending.isEmpty, true);
    });
  });
}

class _RegRepo implements AgencyRegistrationRepository {
  Either<Failure, RegistrationChallenge> startResult = const Left(ServerFailure('x'));

  @override
  Future<Either<Failure, RegistrationChallenge>> start({
    required AgencyRegistrationDraft draft,
    required String password,
  }) async =>
      startResult;

  @override
  Future<Either<Failure, RegistrationChallenge>> resendCode({required String challengeToken}) async =>
      const Left(ServerFailure('x'));

  @override
  Future<Either<Failure, String>> verifyPhone({required String challengeToken, required String code}) async =>
      const Left(ServerFailure('x'));

  @override
  Future<Either<Failure, void>> complete({
    required String verificationToken,
    required RegistrationConsent consent,
  }) async =>
      const Left(ServerFailure('x'));
}

class _UploadRepo implements MissingDocumentRepository {
  final started = Completer<void>();
  final gate = Completer<Either<Failure, void>>();

  @override
  Future<Either<Failure, MissingDocumentRequest>> getMissingDocument(String requestId) async => Right(
        MissingDocumentRequest(
          requestId: 'r1',
          referenceId: 'SB-20476',
          documentTitle: 'جواز',
          reason: 'غير واضح',
          deadline: DateTime(2026, 10, 17),
        ),
      );

  @override
  Future<Either<Failure, void>> upload({
    required String requestId,
    required PickedDocument document,
    void Function(double fraction)? onProgress,
  }) {
    started.complete();
    return gate.future;
  }
}

class _Picker implements DocumentPicker {
  @override
  Future<Either<Failure, PickedDocument?>> pick(DocumentSource source, {required List<String> allowedExtensions}) async =>
      const Right(PickedDocument(path: '/tmp/p.jpg', fileName: 'p.jpg', sizeBytes: 1000));
}
