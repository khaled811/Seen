// Wire shapes of the account screens, against `docs/api/mobile-api-reference.md`
// (`portalAccount`, `agentStaff`, `User`). Unknown words fall back to the safest
// reading, never a crash.
import '../../../../core/localization/app_language.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/agency_profile.dart';
import '../../domain/entities/service_margin.dart';
import '../../domain/entities/team_member.dart';

/// `PortalAgency` + the signed-in person of `portalAccount`.
///
/// The contract has no agency documents, no verification date and no manager of
/// the agency: documents stay empty, and the manager's name is the signed-in
/// person's only when that person is the owner.
AgencyProfile agencyProfileFromPortal(Map<String, dynamic> account) {
  final agency = account['agency'] as Map<String, dynamic>;
  final user = account['user'] as Map<String, dynamic>?;
  final status = agency['status'] as String?;
  final verification = switch (status) {
    'pending' => AgencyVerification.pending,
    'rejected' => AgencyVerification.rejected,
    _ => agency['isVerified'] == true ? AgencyVerification.verified : AgencyVerification.unverified,
  };
  return AgencyProfile(
    name: agency['name'] as String? ?? '',
    licenseNumber: agency['licenseNumber'] as String? ?? '',
    city: agency['city'] as String? ?? '',
    managerName: user?['position'] == 'owner' ? (user?['fullName'] as String? ?? '') : '',
    verification: verification,
  );
}

/// `agentPosition` of a `User`: `owner`, `branch_manager`, `staff`. Anything else is
/// read as the lowest role.
TeamRole roleFromPosition(String? v) => switch (v) {
      'owner' => TeamRole.owner,
      'branch_manager' => TeamRole.branchManager,
      _ => TeamRole.staff,
    };

String positionOf(TeamRole r) => switch (r) {
      TeamRole.owner => 'owner',
      TeamRole.branchManager => 'branch_manager',
      TeamRole.staff => 'staff',
    };

/// A `User` as a team member. The contract says nothing about a user's branch or a
/// pending invitation, so [branchName] is only known right after creating one.
TeamMember teamMemberFromUser(Map<String, dynamic> j, {String? branchName}) => TeamMember(
      id: j['id'] as String? ?? '',
      name: j['fullName'] as String? ?? '',
      role: roleFromPosition(j['agentPosition'] as String?),
      status: j['isActive'] == false ? TeamMemberStatus.disabled : TeamMemberStatus.active,
      branchName: branchName,
    );

/// The margins an agency gives [agentId], from `availableServices` (the services and
/// the agency's own price) and the agent's `serviceEnablements`.
///
/// Only the services enabled for that agency are listed. A percentage is kept as
/// basis points; a fixed price is shown as the amount above the agency's own price
/// (never negative). No history exists on the API, so none is returned.
MarginsOverview marginsFromJson(Map<String, dynamic> j, String agentId, AppLanguage language) {
  final services = {
    for (final s in (j['availableServices'] as List<dynamic>).cast<Map<String, dynamic>>()) s['id'] as String: s,
  };
  final tree = (j['agentTree'] as List<dynamic>).cast<Map<String, dynamic>>().where((a) => a['id'] == agentId);
  final rows = tree.isEmpty ? const <Map<String, dynamic>>[] : (tree.first['serviceEnablements'] as List<dynamic>).cast<Map<String, dynamic>>();
  final margins = <ServiceMargin>[];
  for (final row in rows) {
    if (row['enabled'] != true) continue;
    final id = (row['serviceType'] as Map<String, dynamic>)['id'] as String;
    final service = services[id];
    if (service == null) continue;
    final base = service['myPrice'] == null ? null : MoneyParser.centsFromDecimalString(service['myPrice'] as String);
    final percent = row['markupPercent'] as String?;
    final override = row['overridePrice'] as String?;
    final isPercent = percent != null;
    var value = 0;
    if (isPercent) {
      value = MoneyParser.centsFromDecimalString(percent);
    } else if (override != null && base != null) {
      value = MoneyParser.centsFromDecimalString(override) - base;
      if (value < 0) value = 0;
    }
    margins.add(ServiceMargin(
      serviceId: id,
      serviceName: language.pick(ar: service['nameAr'] as String?, en: service['nameEn'] as String?),
      kind: isPercent ? MarginKind.percent : MarginKind.fixed,
      value: value,
      // A fixed margin needs the agency's own price to become a price.
      editable: isPercent || base != null,
      basePriceCents: base,
    ));
  }
  return MarginsOverview(margins: margins);
}
