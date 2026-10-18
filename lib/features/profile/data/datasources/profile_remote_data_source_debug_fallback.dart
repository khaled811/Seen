import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/agency_profile.dart';
import '../../domain/entities/service_margin.dart';
import '../../domain/entities/team_member.dart';
import '../models/profile_dtos.dart';
import 'profile_remote_data_source.dart';

/// DEBUG ONLY: when a real call fails in a debug build, answer from an in-memory
/// copy of the Figma sample data so the three screens can be used without a backend.
/// `kDebugMode` is a compile-time constant, so release builds drop every fallback
/// branch (same pattern as the other features). Nothing is persisted.
class DebugFallbackProfileRemoteDataSource implements ProfileRemoteDataSource {
  DebugFallbackProfileRemoteDataSource(this._real);

  final ProfileRemoteDataSource _real;

  late List<ServiceMargin> _margins = [
    const ServiceMargin(
        serviceId: 'saudi-visa', serviceName: 'تأشيرة السعودية', kind: MarginKind.fixed, value: 1000, editable: true, iconKey: 'visa'),
    const ServiceMargin(
        serviceId: 'egypt-entry', serviceName: 'دخول مصر', kind: MarginKind.fixed, value: 500, editable: true, iconKey: 'entry'),
    const ServiceMargin(
        serviceId: 'india-visa', serviceName: 'تأشيرة الهند', kind: MarginKind.fixed, value: 800, editable: true, iconKey: 'visa'),
    const ServiceMargin(
        serviceId: 'flights', serviceName: 'حجز طيران', kind: MarginKind.percent, value: 300, editable: false, iconKey: 'flight'),
  ];
  final List<MarginChange> _history = [];

  final List<TeamMember> _team = [
    const TeamMember(id: 'u1', name: 'Majd Alhakeem', role: TeamRole.owner, status: TeamMemberStatus.active),
    const TeamMember(
        id: 'u2', name: 'وليد ناصر', role: TeamRole.branchManager, status: TeamMemberStatus.active, branchName: 'فرع عدن'),
    const TeamMember(id: 'u3', name: 'هدى سالم', role: TeamRole.staff, status: TeamMemberStatus.active, branchName: 'فرع صنعاء'),
    const TeamMember(id: 'u4', name: 'أنور عبدالكريم', role: TeamRole.staff, status: TeamMemberStatus.invited, branchName: 'فرع تعز'),
    const TeamMember(id: 'u5', name: 'فهد العبسي', role: TeamRole.staff, status: TeamMemberStatus.disabled, branchName: 'فرع صنعاء'),
  ];
  int _nextId = 100;

  MarginsOverviewDto _overview() => MarginsOverviewDto(MarginsOverview(margins: List.of(_margins), history: List.of(_history)));

  @override
  Future<Either<Failure, AgencyProfileDto>> getAgencyProfile() async {
    final result = await _real.getAgencyProfile();
    if (kDebugMode && result.isLeft()) {
      final now = DateTime.now();
      return Right(AgencyProfileDto(AgencyProfile(
        name: 'جُباري للسياحة والسفر',
        licenseNumber: 'TL-0042',
        city: 'صنعاء',
        managerName: 'Majd Alhakeem',
        verification: AgencyVerification.verified,
        verifiedAt: DateTime(2024, 3, 12),
        documents: [
          AgencyDocument(id: 'cr', kind: AgencyDocumentKind.commercialRegister, expiresAt: now.add(const Duration(days: 23))),
          AgencyDocument(id: 'tl', kind: AgencyDocumentKind.tourismLicense, expiresAt: DateTime(now.year + 1, 6, 30)),
        ],
      )));
    }
    return result;
  }

  @override
  Future<Either<Failure, MarginsOverviewDto>> getMargins() async {
    final result = await _real.getMargins();
    if (kDebugMode && result.isLeft()) return Right(_overview());
    return result;
  }

  @override
  Future<Either<Failure, MarginsOverviewDto>> saveMargins(Map<String, int> changes) async {
    final result = await _real.saveMargins(changes);
    if (kDebugMode && result.isLeft()) {
      final now = DateTime.now();
      _margins = [
        for (final m in _margins)
          if (changes.containsKey(m.serviceId) && m.editable) () {
            _history.insert(0, MarginChange(
              serviceName: m.serviceName, kind: m.kind, from: m.value, to: changes[m.serviceId]!, at: now, by: 'Majd'));
            return m.withValue(changes[m.serviceId]!);
          }() else m,
      ];
      return Right(_overview());
    }
    return result;
  }

  @override
  Future<Either<Failure, List<TeamMember>>> getTeam() async {
    final result = await _real.getTeam();
    if (kDebugMode && result.isLeft()) return Right(List.of(_team));
    return result;
  }

  TeamMember _replace(String id, TeamMember Function(TeamMember) f) {
    final i = _team.indexWhere((m) => m.id == id);
    _team[i] = f(_team[i]);
    return _team[i];
  }

  @override
  Future<Either<Failure, TeamMember>> inviteMember(InviteDraft d) async {
    final result = await _real.inviteMember(d);
    if (kDebugMode && result.isLeft()) {
      final m = TeamMember(
          id: 'u${_nextId++}', name: d.name, role: d.role, status: TeamMemberStatus.invited, branchName: d.branchName);
      _team.add(m);
      return Right(m);
    }
    return result;
  }

  TeamMember _copy(TeamMember m, {TeamRole? role, TeamMemberStatus? status}) =>
      TeamMember(id: m.id, name: m.name, role: role ?? m.role, status: status ?? m.status, branchName: m.branchName);

  @override
  Future<Either<Failure, TeamMember>> changeMemberRole(String id, TeamRole role) async {
    final result = await _real.changeMemberRole(id, role);
    if (kDebugMode && result.isLeft()) return Right(_replace(id, (m) => _copy(m, role: role)));
    return result;
  }

  @override
  Future<Either<Failure, TeamMember>> setMemberActive(String id, {required bool active}) async {
    final result = await _real.setMemberActive(id, active: active);
    if (kDebugMode && result.isLeft()) {
      return Right(_replace(id, (m) => _copy(m, status: active ? TeamMemberStatus.active : TeamMemberStatus.disabled)));
    }
    return result;
  }

  @override
  Future<Either<Failure, bool>> resendInvite(String id) async {
    final result = await _real.resendInvite(id);
    if (kDebugMode && result.isLeft()) return const Right(true);
    return result;
  }

  @override
  Future<Either<Failure, bool>> cancelInvite(String id) async {
    final result = await _real.cancelInvite(id);
    if (kDebugMode && result.isLeft()) {
      _team.removeWhere((m) => m.id == id);
      return const Right(true);
    }
    return result;
  }
}
