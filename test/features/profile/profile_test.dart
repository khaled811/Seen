// ACC-01 / 02 / 03: agency details, profit margins, users and permissions.
// Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/foundation/seen_strings.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/profile/domain/entities/agency_profile.dart';
import 'package:seen_booking/features/profile/domain/entities/service_margin.dart';
import 'package:seen_booking/features/profile/domain/entities/team_member.dart';
import 'package:seen_booking/features/profile/domain/repositories/profile_repositories.dart';
import 'package:seen_booking/features/profile/domain/usecases/profile_usecases.dart';
import 'package:seen_booking/features/profile/presentation/bloc/profile_cubits.dart';
import 'package:seen_booking/features/profile/presentation/screens/agency_details_screen.dart';
import 'package:seen_booking/features/profile/presentation/screens/profit_margin_screen.dart';
import 'package:seen_booking/features/profile/presentation/screens/team_screen.dart';
import 'package:seen_booking/features/profile/presentation/widgets/profile_strings.dart';
import 'package:seen_booking/features/system_status/domain/services/store_launcher.dart';

class _Repo implements AgencyRepository, MarginsRepository, TeamRepository {
  AgencyProfile profile = AgencyProfile(
    name: 'جُباري للسياحة والسفر',
    licenseNumber: 'TL-0042',
    city: 'صنعاء',
    managerName: 'Majd Alhakeem',
    verification: AgencyVerification.verified,
    verifiedAt: DateTime(2024, 3, 12),
    documents: [
      AgencyDocument(id: 'cr', kind: AgencyDocumentKind.commercialRegister, expiresAt: DateTime(2026, 11, 10), viewUrl: 'https://f/cr'),
      AgencyDocument(id: 'tl', kind: AgencyDocumentKind.tourismLicense, expiresAt: DateTime(2027, 6, 30), viewUrl: 'https://f/tl'),
    ],
  );
  Either<Failure, AgencyProfile>? profileFailure;

  List<ServiceMargin> margins = const [
    ServiceMargin(serviceId: 'a', serviceName: 'تأشيرة السعودية', kind: MarginKind.fixed, value: 1000, editable: true),
    ServiceMargin(serviceId: 'f', serviceName: 'حجز طيران', kind: MarginKind.percent, value: 300, editable: false),
  ];
  Map<String, int>? saved;
  bool saveFails = false;

  List<TeamMember> team = const [
    TeamMember(id: 'o', name: 'Majd Alhakeem', role: TeamRole.owner, status: TeamMemberStatus.active),
    TeamMember(id: 'm', name: 'وليد ناصر', role: TeamRole.branchManager, status: TeamMemberStatus.active, branchName: 'فرع عدن'),
    TeamMember(id: 'i', name: 'أنور', role: TeamRole.staff, status: TeamMemberStatus.invited, branchName: 'فرع تعز'),
  ];
  final calls = <String>[];

  @override
  Future<Either<Failure, AgencyProfile>> getProfile() async => profileFailure ?? Right(profile);

  @override
  Future<Either<Failure, MarginsOverview>> getMargins() async => Right(MarginsOverview(margins: margins));

  @override
  Future<Either<Failure, MarginsOverview>> saveMargins(Map<String, int> changes) async {
    saved = changes;
    if (saveFails) {
      return const Left(ServerFailure('x', code: 'INVALID_MARGIN'));
    }
    margins = [for (final m in margins) changes.containsKey(m.serviceId) ? m.withValue(changes[m.serviceId]!) : m];
    return Right(MarginsOverview(margins: margins, history: [
      MarginChange(serviceName: 'تأشيرة السعودية', kind: MarginKind.fixed, from: 1000, to: 1200, at: DateTime(2026, 10, 1), by: 'Majd'),
    ]));
  }

  @override
  Future<Either<Failure, List<TeamMember>>> getMembers() async => Right(team);

  @override
  Future<Either<Failure, TeamMember>> invite(InviteDraft d) async {
    calls.add('invite:${d.name}:${d.role.name}:${d.branchName}');
    return Right(TeamMember(id: 'n', name: d.name, role: d.role, status: TeamMemberStatus.invited, branchName: d.branchName));
  }

  @override
  Future<Either<Failure, TeamMember>> changeRole(String id, TeamRole role) async {
    calls.add('role:$id:${role.name}');
    final m = team.firstWhere((x) => x.id == id);
    return Right(TeamMember(id: id, name: m.name, role: role, status: m.status, branchName: m.branchName));
  }

  @override
  Future<Either<Failure, TeamMember>> setActive(String id, {required bool active}) async {
    calls.add('active:$id:$active');
    final m = team.firstWhere((x) => x.id == id);
    return Right(TeamMember(
        id: id, name: m.name, role: m.role, status: active ? TeamMemberStatus.active : TeamMemberStatus.disabled, branchName: m.branchName));
  }

  @override
  Future<Either<Failure, void>> resendInvite(String id) async {
    calls.add('resend:$id');
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> cancelInvite(String id) async {
    calls.add('cancel:$id');
    return const Right(null);
  }
}

class _Launcher implements StoreLauncher {
  final opened = <String>[];
  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return true;
  }
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.binding.setSurfaceSize(const Size(390, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
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
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    InjectionContainer.instance.init();
  });

  group('AgencyDocument', () {
    final today = DateTime(2026, 10, 18);
    test('expiry states and days left', () {
      AgencyDocument doc(DateTime? at) => AgencyDocument(id: 'x', kind: AgencyDocumentKind.other, expiresAt: at);
      expect(doc(null).expiry(today), DocumentExpiry.none);
      expect(doc(DateTime(2026, 11, 10)).daysLeft(today), 23);
      expect(doc(DateTime(2026, 11, 10)).expiry(today), DocumentExpiry.soon);
      expect(doc(DateTime(2027, 6, 30)).expiry(today), DocumentExpiry.valid);
      expect(doc(DateTime(2026, 10, 17)).expiry(today), DocumentExpiry.expired);
      expect(doc(DateTime(2026, 10, 18)).expiry(today), DocumentExpiry.soon);
    });

    test('expiry wording', () {
      final s = SeenStrings.forLocale(const Locale('ar'));
      expect(s.documentExpiryLine(AgencyDocument(id: 'x', kind: AgencyDocumentKind.other, expiresAt: DateTime(2026, 11, 10)), today), 'ينتهي خلال ٢٣ يومًا');
      expect(s.documentExpiryLine(AgencyDocument(id: 'x', kind: AgencyDocumentKind.other, expiresAt: DateTime(2027, 6, 30)), today), contains('يونيو'));
      expect(s.documentExpiryLine(AgencyDocument(id: 'x', kind: AgencyDocumentKind.other, expiresAt: DateTime(2026, 10, 1)), today), 'انتهت صلاحيته');
    });
  });

  group('margin wording', () {
    final s = SeenStrings.forLocale(const Locale('ar'));
    test('fixed amounts drop empty decimals; percents use Arabic digits', () {
      expect(s.marginValue(MarginKind.fixed, 1000), contains('10 USD'));
      expect(s.marginValue(MarginKind.fixed, 1050), contains('10.50 USD'));
      expect(s.marginValue(MarginKind.percent, 300), '٣٪');
    });
  });

  group('MarginsCubit', () {
    MarginsCubit make(_Repo repo, {bool canEdit = true}) =>
        MarginsCubit(get: GetMarginsUseCase(repo), save: SaveMarginsUseCase(repo), canEdit: canEdit);

    test('edits track dirty; setting the saved value back clears; read-only rows ignored', () async {
      final repo = _Repo();
      final cubit = make(repo);
      await cubit.load();
      cubit.edit('a', 1200);
      expect(cubit.state.dirty, isTrue);
      expect(cubit.state.valueOf(cubit.state.margins.first), 1200);
      cubit.edit('a', 1000);
      expect(cubit.state.dirty, isFalse);
      cubit.edit('f', 500);
      expect(cubit.state.dirty, isFalse);
      await cubit.close();
    });

    test('a viewer cannot edit', () async {
      final cubit = make(_Repo(), canEdit: false);
      await cubit.load();
      cubit.edit('a', 1200);
      expect(cubit.state.dirty, isFalse);
      await cubit.close();
    });

    test('save sends only the edits, then shows the server state and history', () async {
      final repo = _Repo();
      final cubit = make(repo);
      await cubit.load();
      cubit.edit('a', 1200);
      await cubit.save();
      expect(repo.saved, {'a': 1200});
      expect(cubit.state.save, MarginSaveStatus.saved);
      expect(cubit.state.dirty, isFalse);
      expect(cubit.state.history, hasLength(1));
      await cubit.close();
    });

    test('a failed save keeps the edits', () async {
      final repo = _Repo()..saveFails = true;
      final cubit = make(repo);
      await cubit.load();
      cubit.edit('a', 1200);
      await cubit.save();
      expect(cubit.state.save, MarginSaveStatus.failed);
      expect(cubit.state.dirty, isTrue);
      await cubit.close();
    });
  });

  group('TeamCubit', () {
    test('invite adds an invited member; role change and disable update the row; the owner is untouched', () async {
      final repo = _Repo();
      final cubit = TeamCubit(TeamUseCases(repo));
      await cubit.load();
      await cubit.invite(const InviteDraft(name: 'سلمى', phone: '777', role: TeamRole.staff, branchName: 'فرع صنعاء'));
      expect(cubit.state.members.last.status, TeamMemberStatus.invited);
      expect(cubit.state.notice, TeamNotice.invited);
      await cubit.changeRole('m', TeamRole.staff);
      expect(cubit.state.members.firstWhere((m) => m.id == 'm').role, TeamRole.staff);
      await cubit.setActive('m', active: false);
      expect(cubit.state.members.firstWhere((m) => m.id == 'm').status, TeamMemberStatus.disabled);
      await cubit.setActive('o', active: false);
      expect(repo.calls.where((c) => c.startsWith('active:o')), isEmpty);
      await cubit.cancelInvite('i');
      expect(cubit.state.members.any((m) => m.id == 'i'), isFalse);
      await cubit.close();
    });
  });

  group('AgencyDetailsScreen', () {
    testWidgets('shows data, verification, and flags the expiring document with Renew', (tester) async {
      final repo = _Repo();
      final launcher = _Launcher();
      await _pump(
        tester,
        AgencyDetailsScreen(
          createCubit: () => AgencyDetailsCubit(GetAgencyProfileUseCase(repo)),
          launcher: launcher,
          now: DateTime(2026, 10, 18),
        ),
      );
      expect(find.text('بيانات الوكالة'), findsOneWidget);
      expect(find.text('جُباري للسياحة والسفر'), findsOneWidget);
      expect(find.textContaining('تم توثيق الوكالة'), findsOneWidget);
      expect(find.text('ينتهي خلال ٢٣ يومًا'), findsOneWidget);
      expect(find.text('تجديد'), findsOneWidget);
      await tester.tap(find.text('عرض'));
      await tester.pump();
      expect(launcher.opened, ['https://f/tl']);
    });

    testWidgets('Edit and Renew explain that support handles it, no dead buttons', (tester) async {
      final repo = _Repo();
      await _pump(
        tester,
        AgencyDetailsScreen(createCubit: () => AgencyDetailsCubit(GetAgencyProfileUseCase(repo)), now: DateTime(2026, 10, 18)),
      );
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();
      expect(find.textContaining('تواصل مع جُباري'), findsOneWidget);
    });

    testWidgets('a failed first load offers retry', (tester) async {
      final repo = _Repo()..profileFailure = const Left(NetworkFailure('offline'));
      await _pump(tester, AgencyDetailsScreen(createCubit: () => AgencyDetailsCubit(GetAgencyProfileUseCase(repo))));
      expect(find.text('تعذّر التحميل'), findsOneWidget);
      repo.profileFailure = null;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump();
      await tester.pump();
      expect(find.text('جُباري للسياحة والسفر'), findsOneWidget);
    });
  });

  group('ProfitMarginScreen', () {
    MarginsCubit make(_Repo repo) =>
        MarginsCubit(get: GetMarginsUseCase(repo), save: SaveMarginsUseCase(repo));

    testWidgets('edit a margin in the sheet, save, and see the server result', (tester) async {
      final repo = _Repo();
      await _pump(tester, ProfitMarginScreen(createCubit: () => make(repo)));
      expect(find.textContaining('لوكلائك الفرعيين'), findsOneWidget);
      expect(find.textContaining('تحدده جُباري'), findsOneWidget);

      await tester.tap(find.textContaining('10 USD'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '12');
      await tester.tap(find.text('تطبيق'));
      await tester.pumpAndSettle();
      expect(find.textContaining('12 USD'), findsOneWidget);

      await tester.tap(find.text('حفظ التغييرات'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(repo.saved, {'a': 1200});
      expect(find.text('تم حفظ الهامش.'), findsOneWidget);
      expect(find.textContaining('تأشيرة السعودية:'), findsOneWidget); // the change log line
    });

    testWidgets('an invalid number is refused in the sheet', (tester) async {
      final repo = _Repo();
      await _pump(tester, ProfitMarginScreen(createCubit: () => make(repo)));
      await tester.tap(find.textContaining('10 USD'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '.');
      await tester.tap(find.text('تطبيق'));
      await tester.pumpAndSettle();
      expect(find.textContaining('أدخل رقمًا صحيحًا'), findsOneWidget);
    });

    testWidgets('the Save button is off until something changed; the read-only row has no editor', (tester) async {
      final repo = _Repo();
      await _pump(tester, ProfitMarginScreen(createCubit: () => make(repo)));
      await tester.tap(find.text('حفظ التغييرات'), warnIfMissed: false);
      await tester.pump();
      expect(repo.saved, isNull);
      await tester.tap(find.text('٣٪'));
      await tester.pumpAndSettle();
      expect(find.text('تطبيق'), findsNothing);
    });
  });

  group('TeamScreen', () {
    testWidgets('lists the team with status chips, the roles, and invites a user', (tester) async {
      final repo = _Repo();
      await _pump(tester, TeamScreen(createCubit: () => TeamCubit(TeamUseCases(repo)), canManage: true, loadBranches: () async => const []));
      expect(find.text('المستخدمون والصلاحيات'), findsOneWidget);
      expect(find.text('وليد ناصر'), findsOneWidget);
      expect(find.text('دعوة مُرسلة'), findsOneWidget);
      expect(find.text('الأدوار'), findsOneWidget);

      await tester.tap(find.text('دعوة مستخدم'));
      await tester.pumpAndSettle();
      // Empty form: required errors, nothing sent.
      await tester.ensureVisible(find.text('إرسال الدعوة'));
      await tester.tap(find.text('إرسال الدعوة'));
      await tester.pumpAndSettle();
      expect(find.text('هذا الحقل مطلوب.'), findsWidgets);
      expect(repo.calls, isEmpty);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'سلمى');
      await tester.enterText(fields.at(1), '777123456');
      await tester.enterText(fields.at(2), 'فرع صنعاء');
      await tester.ensureVisible(find.text('إرسال الدعوة'));
      await tester.tap(find.text('إرسال الدعوة'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['invite:سلمى:staff:فرع صنعاء']);
      expect(find.text('أرسلنا الدعوة.'), findsOneWidget);
    });

    testWidgets('a row opens its actions; the owner row does not', (tester) async {
      final repo = _Repo();
      await _pump(tester, TeamScreen(createCubit: () => TeamCubit(TeamUseCases(repo)), canManage: true, loadBranches: () async => const []));
      await tester.tap(find.text('Majd Alhakeem'));
      await tester.pumpAndSettle();
      expect(find.text('تغيير الدور'), findsNothing);

      await tester.tap(find.text('أنور'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء الدعوة'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['cancel:i']);
      expect(find.text('أنور'), findsNothing);
    });

    testWidgets('disabling asks first', (tester) async {
      final repo = _Repo();
      await _pump(tester, TeamScreen(createCubit: () => TeamCubit(TeamUseCases(repo)), canManage: true, loadBranches: () async => const []));
      await tester.tap(find.text('وليد ناصر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعطيل المستخدم'));
      await tester.pumpAndSettle();
      expect(find.textContaining('لن يتمكن من الدخول'), findsOneWidget);
      expect(repo.calls, isEmpty);
      await tester.tap(find.text('تعطيل المستخدم').last);
      await tester.pumpAndSettle();
      expect(repo.calls, ['active:m:false']);
      expect(find.text('معطّل'), findsOneWidget);
    });

    testWidgets('someone who is not the owner sees the no-permission screen', (tester) async {
      await _pump(tester, const TeamScreen(canManage: false));
      expect(find.text('ليس لديك صلاحية'), findsOneWidget);
      expect(find.text('دعوة مستخدم'), findsNothing);
    });
  });
}
