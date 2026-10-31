// Loaded-state goldens of the screens the loading system touches. Captured BEFORE any
// loading change and compared again AFTER: the loaded (non-loading) state of a screen
// must stay pixel-identical. The screens are the real ones, fed by the demo data the
// DebugFallback decorators answer with in tests (see test/flutter_test_config.dart).
//
// NOTE: requests list, wallet, top-up history and support tickets show demo dates computed from
// today's date (the demo data uses DateTime.now()), so their date text changes from day to day and
// those four goldens must be regenerated when the day changes. Any other difference is a real
// change of the loaded state.
//
// Update only deliberately: `flutter test test/loading/loaded_state_goldens_test.dart --update-goldens`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/state/branch_scope.dart';
import 'package:seen_booking/core/utils/app_clock.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent.dart';
import 'package:seen_booking/features/agents/domain/entities/sub_agent_request_summary.dart';
import 'package:seen_booking/features/agents/domain/repositories/agents_repository.dart';
import 'package:seen_booking/features/agents/domain/usecases/approve_sub_agent_request_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/fund_sub_agent_wallet_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/get_pending_approval_requests_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/get_sub_agents_usecase.dart';
import 'package:seen_booking/features/agents/domain/usecases/reject_sub_agent_request_usecase.dart';
import 'package:seen_booking/features/agents/presentation/bloc/agents_bloc.dart';
import 'package:seen_booking/features/agents/presentation/bloc/agents_event.dart';
import 'package:seen_booking/features/auth/domain/entities/role_permissions.dart';
import 'package:seen_booking/features/auth/domain/entities/user_session.dart';
import 'package:seen_booking/features/home/presentation/screens/home_screen.dart';
import 'package:seen_booking/features/profile/domain/entities/agency_profile.dart';
import 'package:seen_booking/features/profile/domain/entities/branch.dart';
import 'package:seen_booking/features/profile/domain/entities/service_margin.dart';
import 'package:seen_booking/features/profile/domain/entities/team_member.dart';
import 'package:seen_booking/features/profile/domain/repositories/branch_repository.dart';
import 'package:seen_booking/features/profile/domain/repositories/profile_repositories.dart';
import 'package:seen_booking/features/profile/domain/usecases/profile_usecases.dart';
import 'package:seen_booking/features/profile/presentation/bloc/branches_cubit.dart';
import 'package:seen_booking/features/profile/presentation/bloc/profile_cubits.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/agents/presentation/screens/sub_agents_list_screen.dart';
import 'package:seen_booking/features/profile/presentation/screens/agency_details_screen.dart';
import 'package:seen_booking/features/profile/presentation/screens/branches_screen.dart';
import 'package:seen_booking/features/profile/presentation/screens/profit_margin_screen.dart';
import 'package:seen_booking/features/profile/presentation/screens/team_screen.dart';
import 'package:seen_booking/features/requests/presentation/screens/requests_dashboard_screen.dart';
import 'package:seen_booking/features/services/presentation/screens/drafts_screen.dart';
import 'package:seen_booking/features/services/presentation/screens/service_selection_screen.dart';
import 'package:seen_booking/features/support/presentation/screens/notifications_screen.dart';
import 'package:seen_booking/features/support/presentation/screens/support_tickets_screen.dart';
import 'package:seen_booking/features/wallet/presentation/screens/top_up_history_screen.dart';
import 'package:seen_booking/features/wallet/presentation/screens/wallet_screen.dart';

const _surface = Size(390, 844);

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
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

/// Pumps [screen] and lets the demo data arrive. Not `pumpAndSettle`: some screens keep a
/// ticking clock or a looping animation while loaded.
/// Runs a golden with the app's clock fixed (the Home greeting and the notification groups depend
/// on the time of day), and puts the real clock back afterwards.
Future<void> _atFixedTime(Future<void> Function() body) async {
  final real = AppClock.now;
  AppClock.now = () => DateTime(2026, 10, 21, 19);
  try {
    await body();
  } finally {
    AppClock.now = real;
  }
}

Future<void> _loaded(WidgetTester tester, String name, Widget screen) async {
  await tester.binding.setSurfaceSize(_surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(screen));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await screenMatchesGolden(tester, name);
}

// ---- fixed fixture data for the screens whose real data source has no demo fallback ----

class _ProfileRepo
    implements AgencyRepository, MarginsRepository, TeamRepository {
  @override
  Future<Either<Failure, AgencyProfile>> getProfile() async =>
      Right(AgencyProfile(
        name: 'جُباري للسياحة والسفر',
        licenseNumber: 'TL-0042',
        city: 'صنعاء',
        managerName: 'Majd Alhakeem',
        verification: AgencyVerification.verified,
        verifiedAt: DateTime(2024, 3, 12),
        documents: [
          AgencyDocument(
              id: 'cr',
              kind: AgencyDocumentKind.commercialRegister,
              expiresAt: DateTime(2026, 11, 10),
              viewUrl: 'https://f/cr'),
          AgencyDocument(
              id: 'tl',
              kind: AgencyDocumentKind.tourismLicense,
              expiresAt: DateTime(2027, 6, 30),
              viewUrl: 'https://f/tl'),
        ],
      ));

  @override
  Future<Either<Failure, MarginsOverview>> getMargins(String agentId) async =>
      const Right(MarginsOverview(margins: [
        ServiceMargin(
            serviceId: 'a',
            serviceName: 'تأشيرة السعودية',
            kind: MarginKind.fixed,
            value: 1000,
            editable: true),
        ServiceMargin(
            serviceId: 'f',
            serviceName: 'حجز طيران',
            kind: MarginKind.percent,
            value: 300,
            editable: false),
      ]));

  @override
  Future<Either<Failure, List<TeamMember>>> getMembers() async => const Right([
        TeamMember(
            id: 'o',
            name: 'Majd Alhakeem',
            role: TeamRole.owner,
            status: TeamMemberStatus.active),
        TeamMember(
            id: 'm',
            name: 'وليد ناصر',
            role: TeamRole.branchManager,
            status: TeamMemberStatus.active,
            branchName: 'فرع عدن'),
        TeamMember(
            id: 'i',
            name: 'أنور',
            role: TeamRole.staff,
            status: TeamMemberStatus.invited,
            branchName: 'فرع تعز'),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _BranchRepo implements BranchRepository {
  @override
  Future<Either<Failure, List<Branch>>> list() async => const Right([
        Branch(
            id: 'main',
            name: 'الفرع الرئيسي',
            staffCount: 6,
            requestCount: 124),
        Branch(
            id: 'sanaa',
            name: 'فرع صنعاء',
            staffCount: 3,
            requestCount: 52,
            parentId: 'main'),
        Branch(
            id: 'aden',
            name: 'فرع عدن',
            staffCount: 2,
            requestCount: 41,
            parentId: 'main'),
      ]);

  @override
  Future<Either<Failure, List<BranchStaff>>> staff(String branchId) async =>
      const Right(
          [BranchStaff(id: 'u3', name: 'هدى سالم', role: TeamRole.staff)]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _AgentsRepo implements AgentsRepository {
  @override
  Future<Either<Failure, List<SubAgent>>> getSubAgents() async => const Right([
        SubAgent(
            id: '1',
            name: 'مكتب الريان',
            code: 'AG-101',
            balanceCents: 42000,
            isActive: true),
        SubAgent(
            id: '2',
            name: 'النخبة للسياحة',
            code: 'AG-102',
            balanceCents: 9650,
            isActive: true),
        SubAgent(
            id: '3',
            name: 'سما المكلا',
            code: 'AG-103',
            balanceCents: 0,
            isActive: false),
      ]);

  @override
  Future<Either<Failure, List<SubAgentRequestSummary>>>
      getPendingApprovalRequests() async => const Right([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _WalletRepo implements WalletRepository {
  @override
  Future<Either<Failure, WalletBalance>> getBalance() async => const Right(
        WalletBalance(
            availableCents: 100000,
            holdCents: 0,
            creditLimitCents: 0,
            currency: WalletCurrency.usd),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    InjectionContainer.instance.init();
  });

  testGoldens(
      'home',
      (t) => _atFixedTime(() => _loaded(
          t,
          'loaded/home',
          HomeScreen(
              session: UserSession(
                  userId: 'AG-1',
                  userType: UserType.agent,
                  positionRaw: 'owner',
                  branchId: null,
                  permissionCodes:
                      RolePermissions.defaultCodes[AgentPosition.owner]!)))));
  testGoldens(
      'requests list',
      (t) =>
          _loaded(t, 'loaded/requests_list', const RequestsDashboardScreen()));
  testGoldens(
      'wallet', (t) => _loaded(t, 'loaded/wallet', const WalletScreen()));
  testGoldens('top-up history',
      (t) => _loaded(t, 'loaded/top_up_history', const TopUpHistoryScreen()));
  testGoldens(
      'team',
      (t) => _loaded(
          t,
          'loaded/team',
          TeamScreen(
            createCubit: () => TeamCubit(TeamUseCases(_ProfileRepo())),
            canManage: true,
            loadBranches: () async => const [],
          )));
  testGoldens(
      'profit margin',
      (t) => _loaded(
          t,
          'loaded/profit_margin',
          ProfitMarginScreen(
              agentId: 'a1',
              createCubit: () => MarginsCubit(
                  get: GetMarginsUseCase(_ProfileRepo()),
                  save: SaveMarginsUseCase(_ProfileRepo()),
                  agentId: 'a1'))));
  testGoldens('branches', (t) {
    final scope = BranchScope();
    return _loaded(
        t,
        'loaded/branches',
        BranchesScreen(
          createCubit: () => BranchesCubit(
              branches: _BranchRepo(),
              team: TeamUseCases(_ProfileRepo()),
              scope: scope),
          permissions: RolePermissions.all,
          scope: scope,
        ));
  });
  testGoldens(
      'agency details',
      (t) => _loaded(
          t,
          'loaded/agency_details',
          AgencyDetailsScreen(
              createCubit: () =>
                  AgencyDetailsCubit(GetAgencyProfileUseCase(_ProfileRepo())),
              now: DateTime(2026, 10, 18))));
  testGoldens(
      'support tickets',
      (t) =>
          _loaded(t, 'loaded/support_tickets', const SupportTicketsScreen()));
  testGoldens(
      'notifications',
      (t) => _atFixedTime(() =>
          _loaded(t, 'loaded/notifications', const NotificationsScreen())));
  testGoldens('sub-agents', (t) {
    final agents = _AgentsRepo();
    final bloc = AgentsBloc(
      getSubAgentsUseCase: GetSubAgentsUseCase(agents),
      getPendingApprovalRequestsUseCase:
          GetPendingApprovalRequestsUseCase(agents),
      approveSubAgentRequestUseCase: ApproveSubAgentRequestUseCase(agents),
      rejectSubAgentRequestUseCase: RejectSubAgentRequestUseCase(agents),
      fundSubAgentWalletUseCase: FundSubAgentWalletUseCase(agents),
      getWalletBalanceUseCase: GetWalletBalanceUseCase(_WalletRepo()),
    )..add(const AgentsLoadRequested());
    addTearDown(() => bloc.close().ignore());
    return _loaded(
        t,
        'loaded/sub_agents',
        BlocProvider<AgentsBloc>.value(
            value: bloc, child: const SubAgentsView()));
  });
  testGoldens(
      'drafts', (t) => _loaded(t, 'loaded/drafts', const DraftsScreen()));
  testGoldens(
      'service selection',
      (t) => _loaded(
          t, 'loaded/service_selection', const ServiceSelectionScreen()));
}
