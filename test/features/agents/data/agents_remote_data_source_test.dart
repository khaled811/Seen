// Sub-agencies against the contract: every document is validated against
// `docs/api/mobile-api-reference.md`, and the parsers run on realistic answers.

// ignore: depend_on_referenced_packages
import 'package:gql/language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/features/agents/data/datasources/agents_remote_data_source.dart';
import 'package:seen_booking/features/agents/data/models/sub_agent_dto.dart';
import 'package:seen_booking/features/agents/data/models/sub_agent_profile_dto.dart';
import 'package:seen_booking/features/agents/data/models/sub_agent_request_summary_dto.dart';
import 'package:seen_booking/features/agents/domain/entities/new_sub_agent.dart';

import '../../../support/scripted_graphql_service.dart';

Map<String, Object?> _agent(
  String id, {
  String status = 'active',
  String? balance = '420.50',
  bool canFund = true,
  bool canSuspend = true,
  bool canActivate = false,
}) =>
    {
      'id': id,
      'name': 'مكتب الريان',
      'status': status,
      'city': 'عدن',
      'ownerName': 'وليد',
      'requestCount': 12,
      'monthRequestCount': 4,
      'balance': balance,
      'currency': 'USD',
      'monthMargin': '10.00',
      'createdAt': '2026-03-01T08:00:00+00:00',
      'canFund': canFund,
      'canSuspend': canSuspend,
      'canActivate': canActivate,
    };

AgentsRemoteDataSourceImpl _source(ScriptedGraphQLService graphql) =>
    AgentsRemoteDataSourceImpl(graphQLService: graphql, language: AppLanguage('en'));

void main() {
  group('the list', () {
    test('reads portalAgents and keeps what the server allows per agency', () async {
      final graphql = ScriptedGraphQLService({
        'SubAgents': {
          'portalAgents': {
            'items': [
              _agent('1'),
              _agent('2', status: 'suspended', canFund: false, canSuspend: false, canActivate: true),
              _agent('3', status: 'pending', balance: null),
            ],
          },
        },
      });
      final agents = (((await _source(graphql).getSubAgents()) as Right).value as List<SubAgentDto>).map((d) => d.toEntity()).toList();

      expect(graphql.where('SubAgents').single.variables['limit'], AgentsRemoteDataSourceImpl.pageSize);
      expect(agents[0].isActive, isTrue);
      expect(agents[0].balanceCents, 42050);
      expect(agents[0].code, 'عدن'); // the city: the API has no agency code
      expect((agents[0].canFund, agents[0].canSuspend, agents[0].canActivate), (true, true, false));
      expect(agents[1].isActive, isFalse);
      expect((agents[1].canFund, agents[1].canActivate), (false, true));
      expect(agents[2].invitePending, isTrue);
      // No balance from the server is "unknown", not zero: the screens show a dash.
      expect((agents[0].balanceKnown, agents[2].balanceKnown), (true, false));
    });

    test('missing permission flags fail closed', () {
      final dto = SubAgentDto.fromPortalJson({'id': '1', 'name': 'x', 'status': 'active', 'city': ''});
      expect((dto.canFund, dto.canSuspend, dto.canActivate), (false, false, false));
    });
  });

  group('approvals', () {
    test('pending requests are read with requests(status:) and priced from sellingPrice', () async {
      final graphql = ScriptedGraphQLService({
        'PendingAgentApprovalRequests': {
          'requests': [
            {
              'id': 'r1',
              'referenceCode': 'SB-1',
              'createdAt': '2026-10-01T10:00:00+00:00',
              'sellingPrice': '450.00',
              'serviceType': {'nameAr': 'تأشيرة', 'nameEn': 'Visa'},
              'agent': {'name': 'مكتب الريان'},
              'travelers': [
                {'id': 't1'},
                {'id': 't2'},
              ],
            },
          ],
        },
      });
      final rows = ((await _source(graphql).getPendingApprovalRequests()) as Right).value as List<SubAgentRequestSummaryDto>;
      final entity = rows.single.toEntity();
      expect(printNode(graphql.where('PendingAgentApprovalRequests').single.document), contains('pending_agent_approval'));
      expect((entity.referenceId, entity.serviceName, entity.travelerCount, entity.totalPriceCents), ('SB-1', 'Visa', 2, 45000));
    });

    test('approve and reject are decideMainAgentApproval; the reject reason goes as the note', () async {
      final graphql = ScriptedGraphQLService({
        'DecideMainAgentApproval': {
          'decideMainAgentApproval': {'id': 'r1'},
        },
      });
      final source = _source(graphql);
      expect(((await source.approveRequest('r1')) as Right).value, isTrue);
      expect(((await source.rejectRequest('r2', reason: 'Missing documents')) as Right).value, isTrue);
      final sent = graphql.where('DecideMainAgentApproval');
      expect(sent[0].variables, {'requestId': 'r1', 'approve': true, 'note': ''});
      expect(sent[1].variables, {'requestId': 'r2', 'approve': false, 'note': 'Missing documents'});
    });
  });

  group('funding', () {
    test('topUpSubAgent carries the amount as a decimal string and the idempotency key', () async {
      final graphql = ScriptedGraphQLService({
        'TopUpSubAgent': {
          'topUpSubAgent': {'id': 'w1'},
        },
      });
      final result = await _source(graphql).fundSubAgentWallet(
        subAgentId: '1',
        amountCents: 12550,
        idempotencyKey: 'key-1',
        note: 'weekly',
      );
      expect(result.isRight(), isTrue);
      expect(graphql.where('TopUpSubAgent').single.variables, {
        'subAgentId': '1',
        'amount': '125.50',
        'note': 'weekly',
        'idempotencyKey': 'key-1',
      });
    });

    test('a refusal keeps its code', () async {
      final graphql = ScriptedGraphQLService({'TopUpSubAgent': const ServerFailure('x', code: 'funds_exceed_balance')});
      final failure = ((await _source(graphql).fundSubAgentWallet(subAgentId: '1', amountCents: 1, idempotencyKey: 'k')) as Left).value
          as ServerFailure;
      expect(failure.code, 'funds_exceed_balance');
    });
  });

  group('adding and changing an agency', () {
    test('createSubAgent sends the four SubAgentInput fields and nothing else', () async {
      final graphql = ScriptedGraphQLService({
        'CreateSubAgent': {
          'createSubAgent': {'id': '9', 'name': 'مكتب جديد', 'status': 'pending'},
        },
      });
      final dto = ((await _source(graphql).createSubAgent(const NewSubAgent(
        agencyName: 'مكتب جديد',
        managerName: 'وليد',
        email: 'walid@example.com',
        password: 'Abcdef12-long-pw',
      ))) as Right)
          .value as SubAgentDto;
      expect(graphql.where('CreateSubAgent').single.variables, {
        'input': {
          'name': 'مكتب جديد',
          'ownerFullName': 'وليد',
          'ownerEmail': 'walid@example.com',
          'ownerPassword': 'Abcdef12-long-pw',
        },
      });
      expect(dto.toEntity().invitePending, isTrue);
    });

    test('suspend and activate are setAgentStatus', () async {
      final graphql = ScriptedGraphQLService({
        'SetAgentStatus': {
          'setAgentStatus': {'id': '1', 'status': 'suspended'},
        },
      });
      final source = _source(graphql);
      await source.setSubAgentActive(subAgentId: '1', active: false);
      await source.setSubAgentActive(subAgentId: '1', active: true);
      final sent = graphql.where('SetAgentStatus');
      expect(sent[0].variables, {'agentId': '1', 'status': 'suspended'});
      expect(sent[1].variables, {'agentId': '1', 'status': 'active'});
    });
  });

  group('the profile', () {
    Map<String, Object> answers({Object? statement, Object? requests}) => {
          'SubAgentProfile': {
            'portalAgents': {
              'items': [_agent('1'), _agent('2')],
            },
          },
          'SubAgentStatement': statement ??
              {
                'portalWallet': {
                  'statement': [
                    {
                      'id': 'l1',
                      'type': 'topup',
                      'direction': 'credit',
                      'amount': '300.00',
                      'createdAt': '2026-10-01T10:00:00+00:00',
                      'referenceCode': null,
                    },
                    {
                      'id': 'l2',
                      'type': 'hold',
                      'direction': 'debit',
                      'amount': '1240.00',
                      'createdAt': '2026-09-30T10:00:00+00:00',
                      'referenceCode': 'SB-20484',
                    },
                  ],
                },
              },
          'SubAgentRequests': requests ??
              {
                'requests': [
                  {
                    'id': 'r1',
                    'referenceCode': 'SB-20488',
                    'status': 'processing',
                    'createdAt': '2026-10-01T10:00:00+00:00',
                    'serviceType': {'nameAr': 'تأشيرة', 'nameEn': 'Visa'},
                  },
                  {
                    'id': 'r2',
                    'referenceCode': 'SB-20400',
                    'status': 'completed',
                    'createdAt': '2026-09-01T10:00:00+00:00',
                    'serviceType': {'nameAr': 'تأشيرة', 'nameEn': 'Visa'},
                  },
                ],
              },
        };

    test('is composed from the agency row, its statement and its requests', () async {
      final graphql = ScriptedGraphQLService(answers());
      final profile = (((await _source(graphql).getSubAgentProfile('1')) as Right).value as SubAgentProfileDto).toEntity();
      expect(profile.agent.id, '1');
      expect(profile.city, 'عدن');
      expect(profile.monthlyRequestCount, 4);
      expect(profile.ledger.map((e) => (e.amountCents, e.isCredit, e.referenceCode)), [(30000, true, null), (124000, false, 'SB-20484')]);
      expect(profile.requests.length, 2);
      expect(profile.inProgressRequestCount, 1); // the completed one is not in progress
      expect(graphql.where('SubAgentStatement').single.variables['agentId'], '1');
      expect(graphql.where('SubAgentRequests').single.variables['agentId'], '1');
    });

    test('an agency that is not in the list looks nonexistent', () async {
      final graphql = ScriptedGraphQLService(answers());
      final failure = ((await _source(graphql).getSubAgentProfile('404')) as Left).value as ServerFailure;
      expect(failure.code, 'not_found');
    });

    test('a refused statement leaves the profile without that section; a dropped connection fails it', () async {
      final refused = ScriptedGraphQLService(answers(statement: const ServerFailure('x', code: 'permission_denied')));
      final profile = (((await _source(refused).getSubAgentProfile('1')) as Right).value as SubAgentProfileDto).toEntity();
      expect(profile.ledger, isEmpty);
      expect(profile.requests, isNotEmpty);

      final offline = ScriptedGraphQLService(answers(requests: const NetworkFailure('offline')));
      expect((await _source(offline).getSubAgentProfile('1')).isLeft(), isTrue);
    });
  });
}
