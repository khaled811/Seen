// Agency details, team and branches against the contract: every document is
// validated against `docs/api/mobile-api-reference.md`; what the API does not
// have is refused without a call.

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/features/profile/data/datasources/branch_data_source.dart';
import 'package:seen_booking/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:seen_booking/features/profile/domain/entities/agency_profile.dart';
import 'package:seen_booking/features/profile/domain/entities/branch.dart';
import 'package:seen_booking/features/profile/domain/entities/service_margin.dart';
import 'package:seen_booking/features/profile/domain/entities/team_member.dart';

import '../../support/scripted_graphql_service.dart';

String? _code(Either<Failure, Object?> r) => (((r as Left).value) as ServerFailure).code;

void main() {
  group('agency details (portalAccount)', () {
    Map<String, Object?> account({String status = 'active', bool verified = true, String position = 'owner'}) => {
          'portalAccount': {
            'agency': {'name': 'مكتب الريان', 'status': status, 'isVerified': verified, 'city': 'عدن', 'licenseNumber': 'L-1'},
            'user': {'fullName': 'وليد', 'position': position},
          },
        };

    test('maps the agency and says who the manager is only when the caller is the owner', () async {
      final source = ProfileRemoteDataSourceImpl(graphQLService: ScriptedGraphQLService({'AgencyProfile': account()}), language: AppLanguage('en'));
      final profile = ((await source.getAgencyProfile()) as Right).value as AgencyProfile;
      expect((profile.name, profile.city, profile.licenseNumber, profile.managerName), ('مكتب الريان', 'عدن', 'L-1', 'وليد'));
      expect(profile.verification, AgencyVerification.verified);
      expect(profile.documents, isEmpty); // the contract has no agency documents

      final staff = ProfileRemoteDataSourceImpl(graphQLService: ScriptedGraphQLService({'AgencyProfile': account(position: 'staff')}), language: AppLanguage('en'));
      expect((((await staff.getAgencyProfile()) as Right).value as AgencyProfile).managerName, '');
    });

    test('pending and unverified agencies are told apart', () async {
      Future<AgencyVerification> read(Map<String, Object?> a) async {
        final source = ProfileRemoteDataSourceImpl(graphQLService: ScriptedGraphQLService({'AgencyProfile': a}), language: AppLanguage('en'));
        return (((await source.getAgencyProfile()) as Right).value as AgencyProfile).verification;
      }

      expect(await read(account(status: 'pending', verified: false)), AgencyVerification.pending);
      expect(await read(account(verified: false)), AgencyVerification.unverified);
    });
  });

  group('team', () {
    test('lists agentStaff; the position decides the role and isActive the status', () async {
      final graphql = ScriptedGraphQLService({
        'TeamMembers': {
          'agentStaff': [
            {'id': 'u1', 'fullName': 'Majd', 'agentPosition': 'owner', 'isActive': true},
            {'id': 'u2', 'fullName': 'وليد', 'agentPosition': 'branch_manager', 'isActive': true},
            {'id': 'u3', 'fullName': 'هدى', 'agentPosition': 'staff', 'isActive': false},
          ],
        },
      });
      final members = ((await ProfileRemoteDataSourceImpl(graphQLService: graphql, language: AppLanguage('en')).getTeam()) as Right).value as List<TeamMember>;
      expect(members.map((m) => m.role), [TeamRole.owner, TeamRole.branchManager, TeamRole.staff]);
      expect(members.map((m) => m.status), [TeamMemberStatus.active, TeamMemberStatus.active, TeamMemberStatus.disabled]);
    });

    test('adding a user sends the StaffUserInput; the branch only when one was picked', () async {
      final graphql = ScriptedGraphQLService({
        'CreateStaffUser': {
          'createStaffUser': {'id': 'n', 'fullName': 'سلمى', 'agentPosition': 'staff', 'isActive': true},
        },
      });
      final source = ProfileRemoteDataSourceImpl(graphQLService: graphql, language: AppLanguage('en'));
      final member = ((await source.inviteMember(const InviteDraft(
        name: 'سلمى',
        email: 'salma@example.com',
        password: 'Abcdef12-long-pw',
        role: TeamRole.staff,
        branchName: 'فرع عدن',
        branchId: 'b1',
      ))) as Right)
          .value as TeamMember;
      await source.inviteMember(const InviteDraft(name: 'سلمى', email: 'salma@example.com', password: 'Abcdef12-long-pw', role: TeamRole.staff));
      final sent = graphql.where('CreateStaffUser');
      expect(sent[0].variables['input'], {
        'email': 'salma@example.com',
        'fullName': 'سلمى',
        'password': 'Abcdef12-long-pw',
        'position': 'staff',
        'branchId': 'b1',
      });
      expect((sent[1].variables['input'] as Map).containsKey('branchId'), isFalse);
      expect((member.status, member.branchName), (TeamMemberStatus.active, 'فرع عدن'));
    });

    test('a role change is updateUserRole with the position word', () async {
      final graphql = ScriptedGraphQLService({
        'UpdateUserRole': {
          'updateUserRole': {'id': 'u2', 'fullName': 'وليد', 'agentPosition': 'branch_manager', 'isActive': true},
        },
      });
      final member = ((await ProfileRemoteDataSourceImpl(graphQLService: graphql, language: AppLanguage('en')).changeMemberRole('u2', TeamRole.branchManager)) as Right).value
          as TeamMember;
      expect(graphql.where('UpdateUserRole').single.variables, {'userId': 'u2', 'position': 'branch_manager'});
      expect(member.role, TeamRole.branchManager);
    });
  });

  group('margins of a sub-agency', () {
    Map<String, Object> answers({List<Map<String, Object?>>? rows}) => {
          'AgentMargins': {
            'availableServices': [
              {'id': 'sv1', 'nameAr': 'تأشيرة', 'nameEn': 'Visa', 'code': 'visa', 'myPrice': '100.00', 'priceForAgent': '108.00'},
              {'id': 'sv2', 'nameAr': 'دخول', 'nameEn': 'Entry', 'code': 'entry', 'myPrice': '50.00', 'priceForAgent': '52.50'},
              {'id': 'sv3', 'nameAr': 'طيران', 'nameEn': 'Flight', 'code': 'flight', 'myPrice': '20.00', 'priceForAgent': null},
            ],
            'agentTree': [
              {
                'id': 'sub1',
                'serviceEnablements': rows ??
                    [
                      {'enabled': true, 'overridePrice': '108.00', 'markupPercent': null, 'serviceType': {'id': 'sv1'}},
                      {'enabled': true, 'overridePrice': null, 'markupPercent': '5.00', 'serviceType': {'id': 'sv2'}},
                      {'enabled': false, 'overridePrice': null, 'markupPercent': null, 'serviceType': {'id': 'sv3'}},
                    ],
              },
            ],
          },
        };

    ProfileRemoteDataSourceImpl source(ScriptedGraphQLService g) => ProfileRemoteDataSourceImpl(graphQLService: g, language: AppLanguage('en'));

    test('lists the enabled services; a fixed price is the amount above the own price, a percentage is kept as basis points', () async {
      final graphql = ScriptedGraphQLService(answers());
      final overview = ((await source(graphql).getMargins('sub1')) as Right).value as MarginsOverview;
      expect(graphql.where('AgentMargins').single.variables, {'agentId': 'sub1'});
      expect(overview.margins.map((m) => m.serviceName), ['Visa', 'Entry']); // the disabled one is not listed
      final visa = overview.margins[0];
      expect((visa.kind, visa.value, visa.basePriceCents, visa.editable), (MarginKind.fixed, 800, 10000, true));
      final entry = overview.margins[1];
      expect((entry.kind, entry.value), (MarginKind.percent, 500));
      expect(overview.history, isEmpty);
    });

    test('a price below the own price is shown as no margin, never negative', () async {
      final overview = ((await source(ScriptedGraphQLService(answers(rows: [
        {'enabled': true, 'overridePrice': '90.00', 'markupPercent': null, 'serviceType': {'id': 'sv1'}},
      ]))).getMargins('sub1')) as Right)
          .value as MarginsOverview;
      expect(overview.margins.single.value, 0);
    });

    test('saving sends one setAgentServiceEnablement per change: price for a fixed margin, percent for a percentage; then reads again', () async {
      final graphql = ScriptedGraphQLService({
        ...answers(),
        'SetAgentMargin': {'setAgentServiceEnablement': true},
      });
      final result = await source(graphql).saveMargins('sub1', {'sv1': 1200, 'sv2': 750});
      expect(result.isRight(), isTrue);
      final sent = graphql.where('SetAgentMargin');
      expect(sent[0].variables, {'agentId': 'sub1', 'serviceTypeId': 'sv1', 'enabled': true, 'overridePrice': '112.00', 'markupPercent': null});
      expect(sent[1].variables, {'agentId': 'sub1', 'serviceTypeId': 'sv2', 'enabled': true, 'overridePrice': null, 'markupPercent': '7.50'});
      expect(graphql.where('AgentMargins').length, 2); // before (to know each kind) and after (the server's truth)
    });

    test('the first refusal stops the rest and keeps its code', () async {
      final graphql = ScriptedGraphQLService({
        ...answers(),
        'SetAgentMargin': const ServerFailure('x', code: 'margin_out_of_range'),
      });
      final failure = ((await source(graphql).saveMargins('sub1', {'sv1': 1, 'sv2': 2})) as Left).value as ServerFailure;
      expect(failure.code, 'margin_out_of_range');
      expect(graphql.where('SetAgentMargin').length, 1);
    });

    test('a margin edit never switches a service on: a service that is not enabled is refused without a call', () async {
      final graphql = ScriptedGraphQLService(answers());
      final failure = ((await source(graphql).saveMargins('sub1', {'sv3': 100})) as Left).value as ServerFailure;
      expect(failure.code, 'margin_invalid');
      expect(graphql.where('SetAgentMargin'), isEmpty);
    });
  });

  group('branches (agentTree)', () {
    Map<String, Object?> tree() => {
          'portalAccount': {
            'agency': {'id': 'a1'},
          },
          'agentTree': [
            {
              'id': 'a1',
              'branches': [
                {
                  'id': 'b1',
                  'name': 'فرع عدن',
                  'manager': {'id': 'u2', 'fullName': 'وليد'},
                },
                {'id': 'b2', 'name': 'فرع تعز', 'manager': null},
              ],
            },
            {
              'id': 'a2', // a sub-agency's: not this agency's branches
              'branches': [
                {'id': 'bx', 'name': 'other', 'manager': null},
              ],
            },
          ],
        };

    test('lists only the own agency\'s branches, flat and without invented counts', () async {
      final source = BranchRemoteDataSource(graphQLService: ScriptedGraphQLService({'Branches': tree()}));
      final branches = ((await source.list()) as Right).value as List<Branch>;
      expect(branches.map((b) => b.name), ['فرع عدن', 'فرع تعز']);
      expect(branches.every((b) => b.staffCount == null && b.requestCount == null && b.isMain), isTrue);
    });

    test('the people of a branch are its manager', () async {
      final source = BranchRemoteDataSource(graphQLService: ScriptedGraphQLService({'Branches': tree()}));
      final withManager = ((await source.staff('b1')) as Right).value as List<BranchStaff>;
      expect((withManager.single.name, withManager.single.role), ('وليد', TeamRole.branchManager));
      expect(((await source.staff('b2')) as Right).value, isEmpty);
    });

    test('creating a branch reads the agency id first, then createBranch(agentId, name)', () async {
      final graphql = ScriptedGraphQLService({
        'BranchesAgency': {
          'portalAccount': {
            'agency': {'id': 'a1'},
          },
        },
        'CreateBranch': {
          'createBranch': {'id': 'b9', 'name': 'فرع المكلا', 'manager': null},
        },
      });
      final branch = ((await BranchRemoteDataSource(graphQLService: graphql).create('فرع المكلا')) as Right).value as Branch;
      expect(graphql.where('CreateBranch').single.variables, {'agentId': 'a1', 'name': 'فرع المكلا'});
      expect(branch.id, 'b9');
    });

    test('moving a user keeps their position and sets the branch', () async {
      final graphql = ScriptedGraphQLService({
        'BranchMemberPosition': {
          'agentStaff': [
            {'id': 'u3', 'agentPosition': 'staff'},
          ],
        },
        'MoveUserToBranch': {
          'updateUserRole': {'id': 'u3'},
        },
      });
      final source = BranchRemoteDataSource(graphQLService: graphql);
      expect((await source.assign(memberId: 'u3', branchId: 'b1')).isRight(), isTrue);
      expect(graphql.where('MoveUserToBranch').single.variables, {'userId': 'u3', 'position': 'staff', 'branchId': 'b1'});

      final unknown = await source.assign(memberId: 'ghost', branchId: 'b1');
      expect(_code(unknown), 'not_found');
      expect(graphql.where('MoveUserToBranch').length, 1); // nothing was sent for the unknown user
    });
  });
}
