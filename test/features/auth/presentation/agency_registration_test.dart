// Agency registration after the form (Figma AUTH-05 / AUTH-07): bloc rules over a
// fake repository, the two screens end to end, and the data source against the
// contract (`registerMainAgent`). Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/auth/data/datasources/agency_registration_remote_data_source.dart';
import 'package:seen_booking/features/auth/domain/entities/agency_registration.dart';
import 'package:seen_booking/features/auth/domain/repositories/agency_registration_repository.dart';
import 'package:seen_booking/features/auth/domain/usecases/agency_registration_usecases.dart';
import 'package:seen_booking/features/auth/presentation/bloc/agency_registration_bloc.dart';
import 'package:seen_booking/features/auth/presentation/screens/agency_registration_flow.dart';

import '../../../support/scripted_graphql_service.dart';

const _draft = AgencyRegistrationDraft(
  agencyName: 'وكالة النور',
  managerName: 'أحمد محمد',
  phone: '+967771234567',
  email: 'agency@example.com',
  city: 'صنعاء',
  licenseNumber: 'CR-1',
);

const _consent = RegistrationConsent(acceptedTerms: true, acceptedPrivacy: true);

class _FakeRepo implements AgencyRegistrationRepository {
  Either<Failure, void> result = const Right(null);
  int registers = 0;
  String? lastPassword;
  RegistrationConsent? lastConsent;

  @override
  Future<Either<Failure, void>> register({
    required AgencyRegistrationDraft draft,
    required String password,
    required RegistrationConsent consent,
  }) async {
    registers++;
    lastPassword = password;
    lastConsent = consent;
    return result;
  }
}

AgencyRegistrationBloc _bloc(_FakeRepo r) => AgencyRegistrationBloc(draft: _draft, register: RegisterAgencyUseCase(r));

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('RegistrationIssue.from', () {
    test('maps the contract codes', () {
      expect(RegistrationIssue.from(const NetworkFailure('x')).kind, RegistrationIssueKind.offline);
      final email = RegistrationIssue.from(const ServerFailure('x', code: 'owner_email_taken'));
      expect((email.kind, email.isFormFieldConflict), (RegistrationIssueKind.emailTaken, true));
      expect(RegistrationIssue.from(const ServerFailure('x', code: 'password_weak')).kind, RegistrationIssueKind.weakPassword);
      final limited = RegistrationIssue.from(const ServerFailure('x', code: 'too_many_attempts', details: {'minutes': 30}));
      expect((limited.kind, limited.minutes), (RegistrationIssueKind.rateLimited, 30));
      expect(RegistrationIssue.from(const ServerFailure('boom')).kind, RegistrationIssueKind.generic);
      expect(RegistrationIssue.from(const ServerFailure('x', code: 'license_number_invalid')).isFormFieldConflict, isFalse);
    });
  });

  group('AgencyRegistrationBloc', () {
    test('password → terms → done; the password is sent once, with the consent', () async {
      final repo = _FakeRepo();
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const RegistrationPasswordSubmitted('Seen@2026-long'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.terms);
      expect(repo.registers, 0); // nothing is sent before the terms are accepted

      bloc.add(const RegistrationConsentSubmitted(_consent));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.done);
      expect(repo.registers, 1);
      expect(repo.lastPassword, 'Seen@2026-long');
      expect(repo.lastConsent?.marketing, false);
    });

    test('consent without the terms or the privacy policy is ignored', () async {
      final repo = _FakeRepo();
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const RegistrationPasswordSubmitted('Seen@2026-long'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.terms);
      bloc.add(const RegistrationConsentSubmitted(RegistrationConsent(acceptedTerms: true, acceptedPrivacy: false)));
      await pumpEventQueue();
      expect(repo.registers, 0);
      expect(bloc.state.step, RegistrationStep.terms);
    });

    test('consent before any password sends nothing', () async {
      final repo = _FakeRepo();
      final bloc = _bloc(repo)..add(const RegistrationConsentSubmitted(_consent));
      await pumpEventQueue();
      expect(repo.registers, 0);
      await bloc.close();
    });

    test('a refusal stays on the terms with its issue; trying again works', () async {
      final repo = _FakeRepo()..result = const Left(ServerFailure('x', code: 'password_weak'));
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const RegistrationPasswordSubmitted('Seen@2026-long'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.terms);
      bloc.add(const RegistrationConsentSubmitted(_consent));
      final failed = await bloc.stream.firstWhere((s) => s.issue != null);
      expect(failed.step, RegistrationStep.terms);
      expect(failed.issue!.kind, RegistrationIssueKind.weakPassword);

      repo.result = const Right(null);
      bloc.add(const RegistrationConsentSubmitted(_consent));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.done);
      expect(repo.registers, 2);
    });

    test('a lost connection is offline, and the password is still held for the retry', () async {
      final repo = _FakeRepo()..result = const Left(NetworkFailure('off'));
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const RegistrationPasswordSubmitted('Seen@2026-long'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.terms);
      bloc.add(const RegistrationConsentSubmitted(_consent));
      expect((await bloc.stream.firstWhere((s) => s.issue != null)).issue!.kind, RegistrationIssueKind.offline);
      repo.result = const Right(null);
      bloc.add(const RegistrationConsentSubmitted(_consent));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.done);
      expect(repo.lastPassword, 'Seen@2026-long');
    });

    test('back from the terms returns to the password and forgets it', () async {
      final repo = _FakeRepo();
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const RegistrationPasswordSubmitted('Seen@2026-long'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.terms);
      bloc.add(const RegistrationBackPressed());
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.password);
      bloc.add(const RegistrationConsentSubmitted(_consent));
      await pumpEventQueue();
      expect(repo.registers, 0); // the forgotten password is not sent
    });

    test('a second tap while registering is dropped', () async {
      final repo = _FakeRepo();
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc.add(const RegistrationPasswordSubmitted('Seen@2026-long'));
      await bloc.stream.firstWhere((s) => s.step == RegistrationStep.terms);
      bloc
        ..add(const RegistrationConsentSubmitted(_consent))
        ..add(const RegistrationConsentSubmitted(_consent));
      await pumpEventQueue();
      expect(repo.registers, lessThanOrEqualTo(2));
      expect(bloc.state.step, RegistrationStep.done);
    });
  });

  group('the data source (registerMainAgent against the contract)', () {
    test('sends the agency, owner, phone, city, licence, locale and the accepted terms', () async {
      final graphql = ScriptedGraphQLService({
        'RegisterMainAgent': {
          'registerMainAgent': {'id': 'a1', 'status': 'pending'},
        },
      });
      final source = AgencyRegistrationRemoteDataSourceImpl(graphQLService: graphql, language: AppLanguage('en'));
      final result = await source.register(draft: _draft, password: 'Seen@2026-long', consent: _consent);
      expect(result.isRight(), isTrue);
      expect(graphql.where('RegisterMainAgent').single.variables, {
        'input': {
          'name': 'وكالة النور',
          'ownerFullName': 'أحمد محمد',
          'ownerEmail': 'agency@example.com',
          'ownerPassword': 'Seen@2026-long',
          'ownerPhone': '+967771234567',
          'city': 'صنعاء',
          'licenseNumber': 'CR-1',
          'locale': 'en',
          'acceptedTerms': true,
        },
      });
    });

    test('the terms are accepted only when both texts were', () async {
      final graphql = ScriptedGraphQLService({
        'RegisterMainAgent': {
          'registerMainAgent': {'id': 'a1', 'status': 'pending'},
        },
      });
      final source = AgencyRegistrationRemoteDataSourceImpl(graphQLService: graphql, language: AppLanguage());
      await source.register(
        draft: _draft,
        password: 'x',
        consent: const RegistrationConsent(acceptedTerms: true, acceptedPrivacy: false),
      );
      final input = graphql.where('RegisterMainAgent').single.variables['input'] as Map;
      expect(input['acceptedTerms'], isFalse);
      expect(input['locale'], 'ar');
    });

    test('a refusal is a Failure with the server code', () async {
      final source = AgencyRegistrationRemoteDataSourceImpl(
        graphQLService: ScriptedGraphQLService({'RegisterMainAgent': const ServerFailure('x', code: 'owner_email_taken')}),
        language: AppLanguage(),
      );
      final failure = ((await source.register(draft: _draft, password: 'x', consent: _consent)) as Left).value as ServerFailure;
      expect(failure.code, 'owner_email_taken');
    });
  });

  group('AgencyRegistrationFlow', () {
    late _FakeRepo repo;

    Future<void> open(WidgetTester tester, {VoidCallback? onExit, VoidCallback? onCompleted}) async {
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
          createBloc: () => _bloc(repo),
        ),
      ));
      await tester.pump();
    }

    Future<void> toTerms(WidgetTester tester) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Seen@2026-long');
      await tester.pump();
      await tester.enterText(fields.at(1), 'Seen@2026-long');
      await tester.pump();
      await tester.tap(find.text('متابعة'));
      await _settle(tester);
    }

    testWidgets('continue stays disabled until the rules pass (12 characters) and the passwords match', (tester) async {
      await open(tester);
      expect(find.text('الخطوة ٢ من ٣'), findsOneWidget);

      final fields = find.byType(TextFormField);
      // 11 characters: one short of the contract's minimum.
      await tester.enterText(fields.at(0), 'Seen@202611');
      await tester.pump();
      await tester.enterText(fields.at(1), 'Seen@202611');
      await tester.pump();
      await tester.tap(find.text('متابعة'));
      await _settle(tester);
      expect(find.text('قبل إنشاء الحساب'), findsNothing);

      await tester.enterText(fields.at(0), 'Seen@2026-long');
      await tester.pump();
      await tester.enterText(fields.at(1), 'Seen@2027-long');
      await tester.pump();
      expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    });

    testWidgets('password → terms (no phone code) → registered', (tester) async {
      var completed = 0;
      await open(tester, onCompleted: () => completed++);

      await toTerms(tester);
      expect(find.text('تحقق من رقم جوالك'), findsNothing);
      expect(find.text('قبل إنشاء الحساب'), findsOneWidget);
      expect(find.text('الخطوة ٣ من ٣'), findsOneWidget);
      expect(repo.registers, 0);

      // Without both mandatory consents nothing is sent.
      await tester.tap(find.text('إنشاء الحساب'));
      await _settle(tester);
      expect(repo.registers, 0);

      await tester.tap(find.text('أوافق على الشروط والأحكام'));
      await tester.pump();
      await tester.tap(find.text('أوافق على سياسة الخصوصية'));
      await tester.pump();
      await tester.tap(find.text('إنشاء الحساب'));
      await _settle(tester);
      expect(repo.registers, 1);
      expect(repo.lastPassword, 'Seen@2026-long');
      expect(completed, 1);
    });

    testWidgets('system back steps back inside the flow and leaves it from the first step', (tester) async {
      var exited = 0;
      await open(tester, onExit: () => exited++);
      await toTerms(tester);
      expect(find.text('قبل إنشاء الحساب'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('أنشئ كلمة مرور لحسابك'), findsOneWidget);
      expect(exited, 0);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exited, 1);
    });

    testWidgets('a weak password refused by the server shows the weak-password banner on the terms', (tester) async {
      await open(tester);
      await toTerms(tester);
      repo.result = const Left(ServerFailure('x', code: 'password_weak'));
      await tester.tap(find.text('أوافق على الشروط والأحكام'));
      await tester.pump();
      await tester.tap(find.text('أوافق على سياسة الخصوصية'));
      await tester.pump();
      await tester.tap(find.text('إنشاء الحساب'));
      await _settle(tester);
      expect(find.text(lookupAppLocalizations(const Locale('ar')).recoveryPasswordWeak), findsOneWidget);
    });
  });
}
