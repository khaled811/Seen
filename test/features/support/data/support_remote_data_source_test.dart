// Support tickets and notifications against the contract: every document is
// validated against `docs/api/mobile-api-reference.md`, and the parsers run on
// realistic answers.

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/features/support/data/datasources/support_remote_data_source.dart';
import 'package:seen_booking/features/support/domain/entities/support_ticket.dart';

import '../../../support/scripted_graphql_service.dart';

Map<String, Object?> _ticket(
  String id, {
  Object? payload = const {'subject': 'Passport photo', 'description': 'It is blurry'},
  String status = 'open',
  bool unread = false,
  Object? related,
}) =>
    {
      'id': id,
      'type': 'general',
      'category': 'general',
      'priority': 'high',
      'status': status,
      'createdAt': '2026-10-18T09:00:00+00:00',
      'payload': payload,
      'isUnread': unread,
      'categoryInfo': {'code': 'general', 'nameAr': 'عام', 'nameEn': 'General'},
      'relatedRequest': related,
    };

Map<String, Object?> _message(String id, String text, {bool support = false}) => {
      'id': id,
      'message': text,
      'createdAt': '2026-10-18T10:00:00+00:00',
      'attachmentFileId': null,
      'attachmentName': '',
      'sender': {
        'id': support ? 'staff' : 'u1',
        'fullName': support ? 'Layla' : 'Amal',
        'agent': support ? null : {'id': 'a1'},
      },
    };

Map<String, Object?> _notification(String id, {bool read = false, Map<String, Object?> extra = const {}}) => {
      'id': id,
      'eventType': 'status_update',
      'kind': 'request',
      'tone': 'info',
      'iconKey': 'doc',
      'isRead': read,
      'createdAt': '2026-10-18T10:00:00+00:00',
      'group': 'today',
      'requestId': null,
      'referenceCode': null,
      'serviceNameAr': null,
      'serviceNameEn': null,
      'travelerLabel': null,
      'travelerLabelMasked': false,
      'amount': null,
      'currency': null,
      'ticketId': null,
      'ticketSubject': null,
      ...extra,
    };

void main() {
  late ScriptedGraphQLService graphql;
  late SupportRemoteDataSourceImpl source;

  void script(Map<String, Object> answers, {String language = 'en'}) {
    graphql = ScriptedGraphQLService(answers);
    source = SupportRemoteDataSourceImpl(graphQLService: graphql, language: AppLanguage(language));
  }

  group('tickets', () {
    test('the list: subject from the payload, no messages, unread marker, related request', () async {
      script({
        'SupportTickets': {
          'tickets': [
            _ticket('t1', unread: true, related: {'id': 'r9', 'referenceCode': 'SB-9'}),
            _ticket('t2', payload: null, status: 'waiting'),
          ],
        },
      });
      final tickets = ((await source.getTickets()) as Right<Failure, List<SupportTicket>>).value;
      expect(tickets.first.subject, 'Passport photo');
      expect(tickets.first.hasUnreadReply, isTrue);
      expect(tickets.first.requestId, 'r9');
      expect(tickets.first.messagesLoaded, isFalse);
      expect(tickets.first.messages, isEmpty);
      expect(tickets.first.priority, TicketPriority.high);
      expect(tickets.last.status, SupportTicketStatus.waiting);
      // No subject in the payload: the ticket is named by its category.
      expect(tickets.last.subject, 'General');
      expect(graphql.where('SupportTickets').single.variables, {'limit': 50, 'offset': 0});
    });

    test('the category name follows the app language', () async {
      script({
        'SupportTickets': {
          'tickets': [_ticket('t2', payload: null)],
        },
      }, language: 'ar');
      final tickets = ((await source.getTickets()) as Right<Failure, List<SupportTicket>>).value;
      expect(tickets.single.subject, 'عام');
    });

    test('a payload that is not an object never breaks the list', () async {
      script({
        'SupportTickets': {
          'tickets': [_ticket('t1', payload: 'garbage'), _ticket('t2', payload: const {'subject': '   '})],
        },
      });
      final tickets = ((await source.getTickets()) as Right<Failure, List<SupportTicket>>).value;
      expect(tickets.map((t) => t.subject), ['General', 'General']);
    });

    test('an unknown status or category is carried as unknown, not a crash', () async {
      script({
        'SupportTickets': {
          'tickets': [_ticket('t1', status: 'hologram')..['category'] = 'live_chat'],
        },
      });
      final ticket = ((await source.getTickets()) as Right<Failure, List<SupportTicket>>).value.single;
      expect(ticket.status, SupportTicketStatus.unknown);
      expect(ticket.category, TicketCategory.unknown);
    });

    test('one ticket carries its thread; who wrote it comes from the agency link', () async {
      script({
        'SupportTicket': {
          'ticket': {
            ..._ticket('t1'),
            'messages': [_message('m1', 'Hello'), _message('m2', 'We looked', support: true)],
          },
        },
      });
      final ticket = ((await source.getTicket('t1')) as Right<Failure, SupportTicket>).value;
      expect(ticket.messagesLoaded, isTrue);
      expect(ticket.messages.map((m) => m.body), ['Hello', 'We looked']);
      expect(ticket.messages.map((m) => m.isSupportReply), [false, true]);
      expect(ticket.messages.last.authorName, 'Layla');
      expect(graphql.where('SupportTicket').single.variables, {'id': 't1'});
    });

    test('a ticket outside the caller scope (null) is "not available"', () async {
      script({
        'SupportTicket': {'ticket': null},
      });
      final failure = ((await source.getTicket('t1')) as Left).value as ServerFailure;
      expect(failure.code, 'ticket_not_found');
    });

    test('opening a general ticket sends the subject, description, category, priority and request', () async {
      script({
        'OpenGeneralTicket': {'openGeneralTicket': _ticket('new')},
      });
      final result = await source.createTicket(
        category: TicketCategory.general,
        subject: 'Passport photo',
        message: 'It is blurry',
        requestId: 'r9',
        priority: TicketPriority.high,
        attachmentFileId: 'f1',
      );
      expect(result.isRight(), isTrue);
      expect(graphql.where('OpenGeneralTicket').single.variables, {
        'subject': 'Passport photo',
        'description': 'It is blurry',
        'category': 'general',
        'priority': 'high',
        'relatedRequestId': 'r9',
        'attachmentFileId': 'f1',
      });
    });

    test('a financial correction cannot be opened from a subject and a message: nothing is sent', () async {
      script(const {});
      final result = await source.createTicket(
        category: TicketCategory.financialCorrection,
        subject: 's',
        message: 'm',
      );
      expect(((result as Left).value as ServerFailure).code, 'unsupported_operation');
      expect(graphql.sent, isEmpty);
    });

    test('a reply returns the message the server stored', () async {
      script({
        'ReplyTicket': {'replyTicket': _message('m9', 'Thanks')},
      });
      final message = ((await source.replyToTicket(ticketId: 't1', message: 'Thanks', attachmentFileId: 'f2')) as Right).value;
      expect(message.id, 'm9');
      expect(message.body, 'Thanks');
      expect(message.isSupportReply, isFalse);
      // An agency never posts an internal note: the document says so explicitly.
      expect(graphql.where('ReplyTicket').single.variables, {'ticketId': 't1', 'message': 'Thanks', 'attachmentFileId': 'f2'});
    });

    test('marking a thread read reads the Boolean', () async {
      script({
        'MarkTicketRead': {'markTicketRead': true},
      });
      expect(((await source.markTicketRead('t1')) as Right).value, isTrue);
    });

    test('a failure of a call is a Failure (not an exception)', () async {
      script({'ReplyTicket': const ServerFailure('x', code: 'permission_denied')});
      final result = await source.replyToTicket(ticketId: 't1', message: 'm');
      expect(result.isLeft(), isTrue);
    });
  });

  group('notifications', () {
    test('a page: structure, money in cents, language-picked service name, unread total', () async {
      script({
        'PortalNotifications': {
          'portalNotifications': {
            'items': [
              _notification('n1', extra: {
                'requestId': 'r1',
                'referenceCode': 'SB-20476',
                'serviceNameAr': 'موافقة',
                'serviceNameEn': 'Approval',
                'travelerLabel': 'A*** S***',
                'travelerLabelMasked': true,
              }),
              _notification('n2', read: true, extra: {'eventType': 'top_up', 'amount': '150.50', 'currency': 'USD'}),
              _notification('n3', extra: {'eventType': 'mystery', 'kind': 'ticket_update', 'ticketId': 'tk1', 'ticketSubject': 'Passport'}),
            ],
            'unreadCount': 7,
            'total': 40,
            'hasMore': true,
          },
        },
      });
      final page = ((await source.getNotifications(limit: 3)) as Right).value;
      expect(page.unreadCount, 7);
      expect(page.total, 40);
      expect(page.hasMore, isTrue);
      final n1 = page.items[0];
      expect(n1.type, NotificationEventType.statusUpdate);
      expect(n1.referenceCode, 'SB-20476');
      expect(n1.relatedRequestId, 'r1');
      expect(n1.serviceName, 'Approval');
      expect(n1.travelerLabel, 'A*** S***');
      expect(page.items[1].amountCents, 15050);
      expect(page.items[1].isRead, isTrue);
      // An event type the app does not know falls back to the kind, then to unknown.
      expect(page.items[2].type, NotificationEventType.ticketUpdate);
      expect(page.items[2].relatedEntityId, 'tk1');
      expect(page.items[2].ticketSubject, 'Passport');
      expect(graphql.where('PortalNotifications').single.variables, {'unreadOnly': false, 'limit': 3, 'offset': 0});
    });

    test('the unread filter and the offset are sent to the server', () async {
      script({
        'PortalNotifications': {
          'portalNotifications': {'items': <Object?>[], 'unreadCount': 0, 'total': 0, 'hasMore': false},
        },
      });
      await source.getNotifications(unreadOnly: true, limit: 20, offset: 40);
      expect(graphql.where('PortalNotifications').single.variables, {'unreadOnly': true, 'limit': 20, 'offset': 40});
    });

    test('the badge asks for one row and reads the unread count', () async {
      script({
        'UnreadNotificationCount': {
          'portalNotifications': {'unreadCount': 4},
        },
      });
      expect(((await source.getUnreadNotificationCount()) as Right).value, 4);
    });

    test('marking one reads a Boolean; marking all reads how many', () async {
      script({
        'MarkNotificationRead': {'markNotificationRead': true},
        'MarkAllNotificationsRead': {'markAllNotificationsRead': 12},
      });
      expect(((await source.markNotificationRead('n1')) as Right).value, isTrue);
      expect(((await source.markAllNotificationsRead()) as Right).value, 12);
      expect(graphql.where('MarkNotificationRead').single.variables, {'notificationId': 'n1'});
    });

    test('a notification the server did not mark comes back false', () async {
      script({
        'MarkNotificationRead': {'markNotificationRead': false},
      });
      expect(((await source.markNotificationRead('n1')) as Right).value, isFalse);
    });

    test('an expired session is reported as such', () async {
      script({'PortalNotifications': const UnauthorizedFailure('over', 'session_expired')});
      expect(((await source.getNotifications()) as Left).value, isA<UnauthorizedFailure>());
    });
  });
}
