// "Copy the details of an earlier request": the documents against the contract, the
// free-JSON parsing, the cubit, and the link on the traveler form.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/services/data/datasources/prefill_remote_data_source.dart';
import 'package:seen_booking/features/services/domain/entities/prefill.dart';
import 'package:seen_booking/features/services/domain/repositories/prefill_repository.dart';
import 'package:seen_booking/features/services/domain/usecases/prefill_usecases.dart';
import 'package:seen_booking/features/services/presentation/bloc/prefill_cubit.dart';
import 'package:seen_booking/features/services/presentation/widgets/prefill_link.dart';

import '../../support/scripted_graphql_service.dart';

const _candidate = PrefillCandidate(requestId: 'r1', referenceCode: 'SB-100', serviceName: 'Circular', travelerCount: 2);

class _Repo implements PrefillRepository {
  Either<Failure, List<PrefillCandidate>> candidatesResult = const Right([_candidate]);
  Either<Failure, PrefillValues> valuesResult = const Right(PrefillValues([
    {'fullName': 'Walid'},
  ]));
  final used = <String>[];

  @override
  Future<Either<Failure, List<PrefillCandidate>>> candidates(String serviceId) async => candidatesResult;

  @override
  Future<Either<Failure, PrefillValues>> valuesFrom({required String serviceId, required String sourceRequestId}) async {
    used.add(sourceRequestId);
    return valuesResult;
  }
}

PrefillCubit _cubit(_Repo repo) =>
    PrefillCubit(candidates: GetPrefillCandidatesUseCase(repo), values: GetPrefillValuesUseCase(repo), serviceId: 's1');

void main() {
  group('PrefillRemoteDataSource', () {
    test('lists candidates in the language shown', () async {
      final graphql = ScriptedGraphQLService({
        'PrefillCandidates': {
          'prefillCandidates': [
            {
              'requestId': 'r1',
              'referenceCode': 'SB-100',
              'serviceNameAr': 'تعميم',
              'serviceNameEn': 'Circular',
              'createdAt': '2026-10-01T10:00:00+00:00',
              'travelerCount': 2,
            },
          ],
        },
      });
      final source = PrefillRemoteDataSource(graphQLService: graphql, language: AppLanguage('en'));
      final list = ((await source.candidates('s1')) as Right).value as List<PrefillCandidate>;
      expect(graphql.where('PrefillCandidates').single.variables, {'serviceTypeId': 's1'});
      expect((list.single.referenceCode, list.single.serviceName, list.single.travelerCount), ('SB-100', 'Circular', 2));
    });

    test('reads the values of one request with the mutation, per traveler', () async {
      final graphql = ScriptedGraphQLService({
        'PrefillFromRequest': {
          'prefillFromRequest': {
            'travelers': [
              {'fullName': 'Walid', 'passportNo': 'A1'},
            ],
          },
        },
      });
      final source = PrefillRemoteDataSource(graphQLService: graphql, language: AppLanguage());
      final values = ((await source.valuesFrom(serviceId: 's1', sourceRequestId: 'r1')) as Right).value as PrefillValues;
      expect(graphql.where('PrefillFromRequest').single.variables, {'serviceTypeId': 's1', 'sourceRequestId': 'r1'});
      expect(values.travelers.single, {'fullName': 'Walid', 'passportNo': 'A1'});
    });

    test('free JSON is read defensively: maps, key/value lists, nulls and nesting', () {
      final v = PrefillRemoteDataSource.parseTravelers([
        {
          'a': 'x',
          'b': null,
          'c': 7,
          'd': {'nested': 1},
          'e': '  ',
        },
        [
          {'key': 'f', 'value': 'y'},
          {'fieldKey': 'g', 'value': 'z'},
          {'value': 'no key'},
        ],
        'garbage',
      ]);
      expect(v.travelers, [
        {'a': 'x', 'c': '7'},
        {'f': 'y', 'g': 'z'},
        <String, String>{},
      ]);
      expect(PrefillRemoteDataSource.parseTravelers(null).travelers, isEmpty);
      expect(v.isEmpty, isFalse);
    });
  });

  group('PrefillCubit', () {
    test('available when the server lists candidates; none when it lists nothing or fails', () async {
      final repo = _Repo();
      final a = _cubit(repo);
      await a.load();
      expect(a.state.status, PrefillStatus.available);
      expect(a.state.candidates, [_candidate]);

      repo.candidatesResult = const Right([]);
      final b = _cubit(repo);
      await b.load();
      expect(b.state.status, PrefillStatus.none);

      repo.candidatesResult = const Left(NetworkFailure('offline'));
      final c = _cubit(repo);
      await c.load();
      expect(c.state.status, PrefillStatus.none); // an optional helper: no link, no error
      await Future.wait([a.close(), b.close(), c.close()]);
    });

    test('using a request returns its values; a failure keeps the link and says why', () async {
      final repo = _Repo();
      final cubit = _cubit(repo);
      await cubit.load();
      final values = await cubit.use('r1');
      expect(values!.travelers.single, {'fullName': 'Walid'});
      expect(repo.used, ['r1']);

      repo.valuesResult = const Left(ServerFailure('x', code: 'not_found'));
      expect(await cubit.use('r1'), isNull);
      expect(cubit.state.status, PrefillStatus.available);
      expect(cubit.state.failure, isA<ServerFailure>());
      await cubit.close();
    });

    test('nothing is read before the candidates are available', () async {
      final repo = _Repo();
      final cubit = _cubit(repo);
      expect(await cubit.use('r1'), isNull);
      expect(repo.used, isEmpty);
      await cubit.close();
    });
  });

  group('PrefillLink', () {
    Widget app(Widget child) => MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light,
          home: Scaffold(body: child),
        );

    testWidgets('shows nothing when there is nothing to copy', (tester) async {
      final repo = _Repo()..candidatesResult = const Right([]);
      await tester.pumpWidget(app(PrefillLink(serviceId: 's1', onValues: (_) {}, createCubit: () => _cubit(repo))));
      await tester.pumpAndSettle();
      expect(find.text('نسخ البيانات من طلب سابق'), findsNothing);
    });

    testWidgets('lists the earlier requests when there are some', (tester) async {
      final repo = _Repo();
      PrefillValues? got;
      await tester.pumpWidget(app(PrefillLink(serviceId: 's1', onValues: (v) => got = v, createCubit: () => _cubit(repo))));
      await tester.pumpAndSettle();
      expect(find.text('نسخ البيانات من طلب سابق'), findsOneWidget);
      await tester.tap(find.text('نسخ البيانات من طلب سابق'));
      await tester.pumpAndSettle();
      expect(find.text('SB-100'), findsOneWidget);
      expect(find.textContaining('Circular'), findsOneWidget);

      await tester.tap(find.text('SB-100'));
      await tester.pumpAndSettle();
      expect(repo.used, ['r1']);
      expect(got!.travelers.single, {'fullName': 'Walid'});
      expect(find.text('عبّأنا الحقول من الطلب السابق. راجعها قبل المتابعة.'), findsOneWidget);
    });
  });
}
