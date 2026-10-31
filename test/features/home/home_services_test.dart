// The home service shortcuts come from `portalHome.services`: the document against the
// contract, the language shown, and a failed refresh keeping what is on screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/features/home/data/datasources/home_remote_data_source.dart';
import 'package:seen_booking/features/home/domain/entities/home_service.dart';
import 'package:seen_booking/features/home/domain/repositories/home_repository.dart';
import 'package:seen_booking/features/home/presentation/bloc/home_services_cubit.dart';

import '../../support/scripted_graphql_service.dart';

class _Repo implements HomeRepository {
  _Repo(this.results);
  final List<Either<Failure, List<HomeService>>> results;
  int calls = 0;

  @override
  Future<Either<Failure, List<HomeService>>> services({int limit = 6}) async => results[calls++];
}

void main() {
  test('asks for six services in one portalHome read and names them in the language shown', () async {
    final graphql = ScriptedGraphQLService({
      'HomeServices': {
        'portalHome': {
          'services': [
            {'id': 's1', 'nameAr': 'تأشيرة', 'nameEn': 'Visa', 'category': 'egypt_national_security'},
            {'id': 's2', 'nameAr': 'دخول', 'nameEn': 'Entry', 'category': 'other'},
          ],
        },
      },
    });
    final list = ((await HomeRemoteDataSource(graphQLService: graphql, language: AppLanguage('en')).services()) as Right).value as List<HomeService>;
    expect(graphql.where('HomeServices').single.variables, {'limit': 6});
    expect(list.map((s) => (s.id, s.name, s.category)), [('s1', 'Visa', 'egypt_national_security'), ('s2', 'Entry', 'other')]);
  });

  test('a failed refresh keeps the shortcuts already shown', () async {
    const first = [HomeService(id: 's1', name: 'Visa', category: 'x')];
    final cubit = HomeServicesCubit(_Repo([const Right(first), const Left(NetworkFailure('offline'))]));
    await cubit.load();
    expect(cubit.state.services, first);
    await cubit.load();
    expect(cubit.state.services, first);
    expect(cubit.state.failure, isA<NetworkFailure>());
    await cubit.close();
  });

  test('two loads at once read once', () async {
    final repo = _Repo([const Right([]), const Right([])]);
    final cubit = HomeServicesCubit(repo);
    await Future.wait([cubit.load(), cubit.load()]);
    expect(repo.calls, 1);
    await cubit.close();
  });
}
