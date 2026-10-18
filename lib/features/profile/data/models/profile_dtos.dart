// TODO(backend-contract): placeholder shapes, see docs/BACKEND_MIGRATION_GAPS.md
// section 33. Unknown enum words fall back to the safest reading, never a crash.
import '../../domain/entities/agency_profile.dart';
import '../../domain/entities/service_margin.dart';
import '../../domain/entities/team_member.dart';

AgencyVerification _verification(String? v) => switch (v) {
      'verified' => AgencyVerification.verified,
      'pending' => AgencyVerification.pending,
      'rejected' => AgencyVerification.rejected,
      _ => AgencyVerification.unverified,
    };

AgencyDocumentKind _docKind(String? v) => switch (v) {
      'commercial_register' => AgencyDocumentKind.commercialRegister,
      'tourism_license' => AgencyDocumentKind.tourismLicense,
      _ => AgencyDocumentKind.other,
    };

MarginKind _marginKind(String? v) => v == 'percent' ? MarginKind.percent : MarginKind.fixed;

TeamRole _role(String? v) => switch (v) {
      'owner' => TeamRole.owner,
      'branch_manager' => TeamRole.branchManager,
      _ => TeamRole.staff,
    };

String roleWire(TeamRole r) => switch (r) {
      TeamRole.owner => 'owner',
      TeamRole.branchManager => 'branch_manager',
      TeamRole.staff => 'staff',
    };

TeamMemberStatus _memberStatus(String? v) => switch (v) {
      'active' => TeamMemberStatus.active,
      'invited' => TeamMemberStatus.invited,
      _ => TeamMemberStatus.disabled,
    };

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

class AgencyProfileDto {
  const AgencyProfileDto(this.entity);

  factory AgencyProfileDto.fromJson(Map<String, dynamic> j) => AgencyProfileDto(AgencyProfile(
        name: j['name'] as String? ?? '',
        licenseNumber: j['licenseNumber'] as String? ?? '',
        city: j['city'] as String? ?? '',
        managerName: j['managerName'] as String? ?? '',
        verification: _verification(j['verification'] as String?),
        verifiedAt: _date(j['verifiedAt']),
        documents: [
          for (final d in (j['documents'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
            AgencyDocument(
              id: d['id'] as String? ?? '',
              kind: _docKind(d['kind'] as String?),
              expiresAt: _date(d['expiresAt']),
              viewUrl: d['viewUrl'] as String?,
            ),
        ],
      ));

  final AgencyProfile entity;
}

class MarginsOverviewDto {
  const MarginsOverviewDto(this.entity);

  factory MarginsOverviewDto.fromJson(Map<String, dynamic> j) => MarginsOverviewDto(MarginsOverview(
        margins: [
          for (final m in (j['margins'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
            ServiceMargin(
              serviceId: m['serviceId'] as String? ?? '',
              serviceName: m['serviceName'] as String? ?? '',
              kind: _marginKind(m['kind'] as String?),
              value: (m['value'] as num?)?.toInt() ?? 0,
              editable: m['editable'] == true,
              iconKey: m['iconKey'] as String?,
            ),
        ],
        history: [
          for (final h in (j['history'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
            MarginChange(
              serviceName: h['serviceName'] as String? ?? '',
              kind: _marginKind(h['kind'] as String?),
              from: (h['from'] as num?)?.toInt() ?? 0,
              to: (h['to'] as num?)?.toInt() ?? 0,
              at: _date(h['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
              by: h['by'] as String? ?? '',
            ),
        ],
      ));

  final MarginsOverview entity;
}

TeamMember teamMemberFromJson(Map<String, dynamic> j) => TeamMember(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      role: _role(j['role'] as String?),
      status: _memberStatus(j['status'] as String?),
      branchName: j['branchName'] as String?,
    );
