// Editing a sub-agency (`updateAgentProfile`): the document against the contract, only the
// changed fields are sent, and the sheet.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/agents/data/datasources/sub_agent_edit_remote_data_source.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent.dart';
import 'package:seen_booking/features/agents/domain/repositories/sub_agent_edit_repository.dart';
import 'package:seen_booking/features/agents/domain/usecases/update_sub_agent_usecase.dart';
import 'package:seen_booking/features/agents/presentation/bloc/edit_sub_agent_cubit.dart';
import 'package:seen_booking/features/agents/presentation/widgets/edit_sub_agent_sheet.dart';

import '../../support/scripted_graphql_service.dart';

class _Repo implements SubAgentEditRepository {
  Either<Failure, void> result = const Right(null);
  final calls = <({String? name, String? owner, String? email})>[];

  @override
  Future<Either<Failure, void>> update({required String agentId, String? name, String? ownerFullName, String? ownerEmail}) async {
    calls.add((name: name, owner: ownerFullName, email: ownerEmail));
    return result;
  }
}

EditSubAgentCubit _cubit(_Repo repo) => EditSubAgentCubit(UpdateSubAgentUseCase(repo), agentId: 'a1', currentName: 'مكتب الريان', currentOwnerName: 'وليد');

const _agent = SubAgent(id: 'a1', name: 'مكتب الريان', code: '', balanceCents: 0, isActive: true, ownerName: 'وليد');

void main() {
  test('updateAgentProfile sends the agent id and the fields given', () async {
    final graphql = ScriptedGraphQLService({
      'UpdateAgentProfile': {
        'updateAgentProfile': {'id': 'a1', 'name': 'جديد'},
      },
    });
    final result = await SubAgentEditRemoteDataSource(graphQLService: graphql).update(agentId: 'a1', name: 'جديد');
    expect(result.isRight(), isTrue);
    expect(graphql.where('UpdateAgentProfile').single.variables, {'agentId': 'a1', 'name': 'جديد', 'ownerFullName': null, 'ownerEmail': null});
  });

  group('EditSubAgentCubit', () {
    test('sends only what changed; blank or unchanged fields are left alone', () async {
      final repo = _Repo();
      final cubit = _cubit(repo);
      await cubit.submit(name: 'مكتب الريان', ownerName: 'وليد ناصر', ownerEmail: '  ');
      expect(repo.calls.single, (name: null, owner: 'وليد ناصر', email: null));
      expect(cubit.state.status, EditAgentStatus.done);
      await cubit.close();
    });

    test('nothing changed: nothing is sent', () async {
      final repo = _Repo();
      final cubit = _cubit(repo);
      await cubit.submit(name: 'مكتب الريان', ownerName: 'وليد', ownerEmail: '');
      expect(repo.calls, isEmpty);
      expect(cubit.state.status, EditAgentStatus.done);
      await cubit.close();
    });

    test('a refusal keeps its code', () async {
      final repo = _Repo()..result = const Left(ServerFailure('x', code: 'owner_email_taken'));
      final cubit = _cubit(repo);
      await cubit.submit(name: 'مكتب الريان', ownerName: 'وليد', ownerEmail: 'a@b.co');
      expect(cubit.state.status, EditAgentStatus.failed);
      expect((cubit.state.failure as ServerFailure).code, 'owner_email_taken');
      await cubit.close();
    });
  });

  group('EditSubAgentSheet', () {
    Future<_Repo> open(WidgetTester tester) async {
      final repo = _Repo();
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
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEditSubAgentSheet(context, subAgent: _agent, createCubit: () => _cubit(repo)),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('starts with the current names; saving sends only the edit', (tester) async {
      final repo = await open(tester);
      expect(find.text('مكتب الريان'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'الريان للسفر');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(repo.calls.single, (name: 'الريان للسفر', owner: null, email: null));
    });

    testWidgets('a malformed e-mail is refused before anything is sent', (tester) async {
      final repo = await open(tester);
      await tester.enterText(find.byType(TextFormField).at(2), 'not-an-email');
      await tester.pump();
      await tester.tap(find.text('حفظ'));
      await tester.pump();
      expect(repo.calls, isEmpty);
      expect(find.text('أدخل بريدًا إلكترونيًا صالحًا.'), findsOneWidget);
    });
  });
}
