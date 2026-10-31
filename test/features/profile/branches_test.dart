// ACC-07 branch management and hierarchy. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/state/branch_scope.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/auth/domain/entities/role_permissions.dart';
import 'package:seen_booking/features/profile/domain/entities/branch.dart';
import 'package:seen_booking/features/profile/domain/entities/team_member.dart';
import 'package:seen_booking/features/profile/domain/repositories/branch_repository.dart';
import 'package:seen_booking/features/profile/domain/repositories/profile_repositories.dart';
import 'package:seen_booking/features/profile/domain/usecases/profile_usecases.dart';
import 'package:seen_booking/features/profile/presentation/bloc/branches_cubit.dart';
import 'package:seen_booking/features/profile/presentation/bloc/profile_cubits.dart';
import 'package:seen_booking/features/profile/presentation/screens/branches_screen.dart';
import 'package:seen_booking/features/profile/presentation/screens/team_screen.dart';

class _Repo implements BranchRepository {
  final branches = <Branch>[
    const Branch(id: 'main', name: 'الفرع الرئيسي', staffCount: 6, requestCount: 124),
    const Branch(id: 'sanaa', name: 'فرع صنعاء', staffCount: 3, requestCount: 52, parentId: 'main'),
    const Branch(id: 'aden', name: 'فرع عدن', staffCount: 2, requestCount: 41, parentId: 'main'),
  ];
  final staffOf = <String, List<BranchStaff>>{
    'sanaa': [const BranchStaff(id: 'u3', name: 'هدى سالم', role: TeamRole.staff)],
    'aden': [
      const BranchStaff(id: 'u2', name: 'وليد ناصر', role: TeamRole.branchManager),
      const BranchStaff(id: 'u7', name: 'سالم بن علي', role: TeamRole.staff),
    ],
    'main': [const BranchStaff(id: 'u1', name: 'Majd', role: TeamRole.owner)],
  };
  final calls = <String>[];
  Failure? listFailure;
  Failure? assignFailure;

  @override
  Future<Either<Failure, List<Branch>>> list() async => listFailure == null ? Right(List.of(branches)) : Left(listFailure!);

  @override
  Future<Either<Failure, List<BranchStaff>>> staff(String branchId) async => Right(List.of(staffOf[branchId] ?? const []));

  @override
  Future<Either<Failure, Branch>> create(String name) async {
    calls.add('create:$name');
    final b = Branch(id: 'new', name: name, staffCount: 0, requestCount: 0, parentId: 'main');
    branches.add(b);
    return Right(b);
  }

  @override
  Future<Either<Failure, void>> assign({required String memberId, required String branchId}) async {
    calls.add('assign:$memberId:$branchId');
    return assignFailure == null ? const Right(null) : Left(assignFailure!);
  }
}

class _Team implements TeamRepository {
  @override
  Future<Either<Failure, List<TeamMember>>> getMembers() async => const Right([
        TeamMember(id: 'u1', name: 'Majd', role: TeamRole.owner, status: TeamMemberStatus.active),
        TeamMember(id: 'u3', name: 'هدى سالم', role: TeamRole.staff, status: TeamMemberStatus.active),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

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

BranchesCubit _cubit(_Repo repo, BranchScope scope) =>
    BranchesCubit(branches: repo, team: TeamUseCases(_Team()), scope: scope);

void main() {
  group('BranchesCubit', () {
    test('loads the tree, focuses the first sub-branch and lists its people', () async {
      final cubit = _cubit(_Repo(), BranchScope());
      await cubit.load();
      expect(cubit.state.status, LoadStatus.loaded);
      expect(cubit.state.focusId, 'sanaa');
      expect(cubit.state.staff.single.name, 'هدى سالم');
      await cubit.close();
    });

    test('the scope is written for the requests screen; null means all branches', () async {
      final scope = BranchScope();
      final cubit = _cubit(_Repo(), scope);
      cubit.setScope('aden');
      expect(scope.value, 'aden');
      cubit.setScope(null);
      expect(scope.value, isNull);
      await cubit.close();
    });

    test('assigning reloads the tree and keeps the branch in focus; a refusal says so', () async {
      final repo = _Repo();
      final cubit = _cubit(repo, BranchScope());
      await cubit.load();
      await cubit.focus('aden');
      await cubit.assign(memberId: 'u3', branchId: 'aden');
      expect(repo.calls, ['assign:u3:aden']);
      expect(cubit.state.focusId, 'aden');
      expect(cubit.state.notice, BranchNotice.assigned);
      repo.assignFailure = const NetworkFailure('off');
      await cubit.assign(memberId: 'u3', branchId: 'sanaa');
      expect(cubit.state.notice, BranchNotice.failed);
      await cubit.close();
    });

    test('creating a branch focuses it; the owner is not offered for assignment', () async {
      final repo = _Repo();
      final cubit = _cubit(repo, BranchScope());
      await cubit.load();
      await cubit.create('فرع حضرموت');
      expect(cubit.state.focusId, 'new');
      expect(cubit.state.branches.any((b) => b.name == 'فرع حضرموت'), isTrue);
      final members = await cubit.assignableMembers();
      expect(members.map((m) => m.id), ['u3']);
      await cubit.close();
    });

    test('a load failure can be retried', () async {
      final repo = _Repo()..listFailure = const NetworkFailure('off');
      final cubit = _cubit(repo, BranchScope());
      await cubit.load();
      expect(cubit.state.status, LoadStatus.failure);
      repo.listFailure = null;
      await cubit.load();
      expect(cubit.state.status, LoadStatus.loaded);
      await cubit.close();
    });
  });

  group('BranchesScreen', () {
    Future<(_Repo, BranchScope)> open(WidgetTester tester, {RolePermissions perms = RolePermissions.all}) async {
      final repo = _Repo();
      final scope = BranchScope();
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(BranchesScreen(createCubit: () => _cubit(repo, scope), permissions: perms, scope: scope)));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      return (repo, scope);
    }

    testWidgets('shows the scope, the tree with counts, and the people of the focused branch', (tester) async {
      await open(tester);
      expect(find.text('الفروع'), findsOneWidget);
      expect(find.text('عرض الطلبات حسب الفرع'), findsOneWidget);
      expect(find.text('كل الفروع'), findsOneWidget);
      expect(find.textContaining('٦ موظفين · '), findsOneWidget);
      expect(find.textContaining('موظفان · '), findsOneWidget);
      expect(find.text('فرع صنعاء · الموظفون'), findsOneWidget);
      await tester.tap(find.text('فرع عدن'));
      await tester.pump();
      await tester.pump();
      expect(find.text('فرع عدن · الموظفون'), findsOneWidget);
      expect(find.text('وليد ناصر'), findsOneWidget);
      expect(find.text('نقل لفرع'), findsNWidgets(2));
    });

    testWidgets('choosing a branch in the scope selector sets the app-wide scope', (tester) async {
      final (_, scope) = await open(tester);
      await tester.tap(find.text('كل الفروع'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('فرع عدن').last);
      await tester.pumpAndSettle();
      expect(scope.value, 'aden');
      expect(find.text('فرع عدن'), findsWidgets);
    });

    testWidgets('moving a person asks for the target branch, then assigns', (tester) async {
      final (repo, _) = await open(tester);
      await tester.tap(find.text('نقل لفرع'));
      await tester.pumpAndSettle();
      // The current branch is not offered as a target.
      expect(find.text('فرع صنعاء'), findsWidgets);
      await tester.tap(find.text('فرع عدن').last);
      await tester.pumpAndSettle();
      expect(repo.calls, ['assign:u3:aden']);
    });

    testWidgets('assign a staff member: pick the person, then the branch', (tester) async {
      final (repo, _) = await open(tester);
      await tester.tap(find.text('تعيين موظف لفرع'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('هدى سالم · موظف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('فرع عدن').last);
      await tester.pumpAndSettle();
      expect(repo.calls, ['assign:u3:aden']);
    });

    testWidgets('the plus adds a branch; an empty name is refused', (tester) async {
      final (repo, _) = await open(tester);
      await tester.tap(find.bySemanticsLabel('إضافة فرع'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إنشاء'));
      await tester.pump();
      expect(find.text('اكتب اسم الفرع.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'فرع حضرموت');
      await tester.tap(find.text('إنشاء'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['create:فرع حضرموت']);
    });

    testWidgets('a non-owner sees the tree but no way to change it', (tester) async {
      await open(tester, perms: const RolePermissions(AgentPosition.branchManager));
      expect(find.text('فرع صنعاء · الموظفون'), findsOneWidget);
      expect(find.text('تعيين موظف لفرع'), findsNothing);
      expect(find.text('نقل لفرع'), findsNothing);
      expect(find.bySemanticsLabel('إضافة فرع'), findsNothing);
    });
  });

  group('invite uses the real branches', () {
    testWidgets('the branch field becomes a picker and the draft carries its id', (tester) async {
      final invited = <InviteDraft>[];
      final repo = _TeamInvite(invited);
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(TeamScreen(
        createCubit: () => TeamCubit(TeamUseCases(repo)),
        canManage: true,
        loadBranches: () async => [const Branch(id: 'aden', name: 'فرع عدن', staffCount: 0, requestCount: 0, parentId: 'main')],
      )));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('إضافة مستخدم'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'سلمى');
      await tester.enterText(fields.at(1), 'salma@example.com');
      await tester.enterText(fields.at(2), 'Abcdef12-long-pw');
      await tester.ensureVisible(fields.at(3));
      await tester.tap(fields.at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('فرع عدن').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('إضافة المستخدم'));
      await tester.tap(find.text('إضافة المستخدم'));
      await tester.pumpAndSettle();
      expect(invited.single.branchId, 'aden');
      expect(invited.single.branchName, 'فرع عدن');
    });
  });
}

class _TeamInvite implements TeamRepository {
  _TeamInvite(this.invited);
  final List<InviteDraft> invited;

  @override
  Future<Either<Failure, List<TeamMember>>> getMembers() async => const Right([
        TeamMember(id: 'o', name: 'Majd', role: TeamRole.owner, status: TeamMemberStatus.active),
      ]);

  @override
  Future<Either<Failure, TeamMember>> invite(InviteDraft draft) async {
    invited.add(draft);
    return Right(TeamMember(id: 'n', name: draft.name, role: draft.role, status: TeamMemberStatus.invited, branchName: draft.branchName));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
