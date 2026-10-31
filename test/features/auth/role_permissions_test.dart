// A signed-in person's abilities are the permissions the server listed for them
// (`me.permissions`): a revoked one hides its control, a missing list grants nothing, and the
// default role lists are the ones the backend gave (2026-10-21).

import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/features/auth/domain/entities/role_permissions.dart';
import 'package:seen_booking/features/auth/domain/entities/user_session.dart';

UserSession _session(Set<String> codes, {String position = 'owner'}) => UserSession(
      userId: 'u',
      userType: UserType.agent,
      positionRaw: position,
      branchId: null,
      permissionCodes: codes,
    );

Set<Capability> _allowed(RolePermissions p) => {for (final c in Capability.values) if (p.can(c)) c};

void main() {
  test('the default owner can do everything the app offers; a branch manager and staff only their part', () {
    expect(_allowed(const RolePermissions(AgentPosition.owner)), Capability.values.toSet());
    expect(_allowed(const RolePermissions(AgentPosition.branchManager)), {Capability.createRequest, Capability.branchRequests, Capability.team});
    expect(_allowed(const RolePermissions(AgentPosition.staff)), {Capability.createRequest});
  });

  test('the default lists are the backend\'s', () {
    expect(RolePermissions.defaultCodes[AgentPosition.staff], {'request.cancel', 'request.submit', 'request.view.own', 'ticket.general.create'});
    expect(RolePermissions.defaultCodes[AgentPosition.branchManager],
        {'request.cancel', 'request.submit', 'request.view.branch', 'staff.create', 'ticket.general.create'});
    expect(RolePermissions.defaultCodes[AgentPosition.owner]!.length, 13);
  });

  test('a session uses its own list: a permission the owner revoked hides that control', () {
    final owner = RolePermissions.defaultCodes[AgentPosition.owner]!;
    final withoutMargin = RolePermissions.fromSession(_session({...owner}..remove('pricing.set_margin')));
    expect(withoutMargin.can(Capability.margins), isFalse);
    expect(withoutMargin.can(Capability.wallet), isTrue);
    expect(withoutMargin.isRestricted, isTrue);
  });

  test('an individual grant shows a control the role does not have by default', () {
    final staffPlusTeam = RolePermissions.fromSession(_session({...RolePermissions.defaultCodes[AgentPosition.staff]!, 'staff.create'}, position: 'staff'));
    expect(staffPlusTeam.can(Capability.team), isTrue);
    expect(staffPlusTeam.can(Capability.wallet), isFalse);
  });

  test('a session with no permissions, or only ones the app does not know, grants nothing (fail closed)', () {
    expect(_allowed(RolePermissions.fromSession(_session({}))), isEmpty);
    expect(_allowed(RolePermissions.fromSession(_session({'something.new'}))), isEmpty);
    expect(_allowed(const RolePermissions(AgentPosition.unknown)), isEmpty);
  });

  test('branches need staff.create and an agency-wide view: a branch manager does not get the branch tree', () {
    expect(const RolePermissions(AgentPosition.branchManager).can(Capability.branches), isFalse);
    expect(const RolePermissions(AgentPosition.owner).can(Capability.branches), isTrue);
  });

  test('no session in scope allows everything (tests, pre-sign-in): the server still decides', () {
    expect(_allowed(RolePermissions.all), Capability.values.toSet());
  });
}
