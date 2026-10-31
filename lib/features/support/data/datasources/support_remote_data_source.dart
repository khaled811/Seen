import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/in_app_notification.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/entities/ticket_message.dart';
import '../models/in_app_notification_dto.dart';
import '../models/support_ticket_dto.dart';
import '../models/ticket_message_dto.dart';

/// Support tickets and notifications against the contract (sections 10.5 and 11).
abstract interface class SupportRemoteDataSource {
  /// One page of the agency's tickets, newest first as the server orders them.
  /// The list carries no messages: open a ticket with [getTicket].
  Future<Either<Failure, List<SupportTicket>>> getTickets({int limit = 50, int offset = 0});

  /// One ticket with its thread.
  Future<Either<Failure, SupportTicket>> getTicket(String ticketId);

  /// `openGeneralTicket`. The created ticket comes back with its first message
  /// as the description.
  Future<Either<Failure, SupportTicket>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
    TicketPriority priority = TicketPriority.normal,
    String? attachmentFileId,
    String? categoryCode,
  });

  /// Marks the thread as read (clears the unread marker).
  Future<Either<Failure, bool>> markTicketRead(String ticketId);

  /// `replyTicket`: the new message. Not idempotent: never resend after a timeout
  /// without the person's say-so.
  Future<Either<Failure, TicketMessage>> replyToTicket({required String ticketId, required String message, String? attachmentFileId});

  Future<Either<Failure, NotificationsPage>> getNotifications({bool unreadOnly = false, int limit = 20, int offset = 0});

  /// The unread total (one row is enough to read it).
  Future<Either<Failure, int>> getUnreadNotificationCount();

  Future<Either<Failure, bool>> markNotificationRead(String notificationId);

  /// How many notifications were marked.
  Future<Either<Failure, int>> markAllNotificationsRead();
}

class SupportRemoteDataSourceImpl implements SupportRemoteDataSource {
  SupportRemoteDataSourceImpl({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQLService = graphQLService,
        _language = language;

  final GraphQLService _graphQLService;
  final AppLanguage _language;

  static const unsupportedCode = 'unsupported_operation';

  static final _ticketsDocument = gql('''
    query SupportTickets(\$limit: Int!, \$offset: Int!) {
      tickets(limit: \$limit, offset: \$offset) {
        ${SupportTicketDto.fields}
      }
    }
  ''');

  static final _ticketDocument = gql('''
    query SupportTicket(\$id: ID!) {
      ticket(id: \$id) {
        ${SupportTicketDto.fields}
        messages { ${TicketMessageDto.fields} }
      }
    }
  ''');

  static final _openTicketDocument = gql('''
    mutation OpenGeneralTicket(
      \$subject: String!
      \$description: String!
      \$category: String!
      \$priority: String
      \$relatedRequestId: ID
      \$attachmentFileId: ID
    ) {
      openGeneralTicket(
        subject: \$subject
        description: \$description
        category: \$category
        priority: \$priority
        relatedRequestId: \$relatedRequestId
        attachmentFileId: \$attachmentFileId
      ) {
        ${SupportTicketDto.fields}
      }
    }
  ''');

  static final _replyDocument = gql('''
    mutation ReplyTicket(\$ticketId: ID!, \$message: String!, \$attachmentFileId: ID) {
      replyTicket(ticketId: \$ticketId, message: \$message, isInternalNote: false, attachmentFileId: \$attachmentFileId) {
        ${TicketMessageDto.fields}
      }
    }
  ''');

  static final _markTicketReadDocument = gql(r'''
    mutation MarkTicketRead($ticketId: ID!) {
      markTicketRead(ticketId: $ticketId)
    }
  ''');

  static const _notificationFields = '''
    id eventType kind tone iconKey isRead createdAt group
    requestId referenceCode serviceNameAr serviceNameEn travelerLabel travelerLabelMasked
    amount currency ticketId ticketSubject
  ''';

  static final _notificationsDocument = gql('''
    query PortalNotifications(\$unreadOnly: Boolean!, \$limit: Int!, \$offset: Int!) {
      portalNotifications(unreadOnly: \$unreadOnly, limit: \$limit, offset: \$offset) {
        items { $_notificationFields }
        unreadCount
        total
        hasMore
      }
    }
  ''');

  static final _unreadCountDocument = gql(r'''
    query UnreadNotificationCount {
      portalNotifications(unreadOnly: true, limit: 1, offset: 0) { unreadCount }
    }
  ''');

  static final _markNotificationReadDocument = gql(r'''
    mutation MarkNotificationRead($notificationId: ID!) {
      markNotificationRead(notificationId: $notificationId)
    }
  ''');

  static final _markAllNotificationsReadDocument = gql(r'''
    mutation MarkAllNotificationsRead {
      markAllNotificationsRead
    }
  ''');

  @override
  Future<Either<Failure, List<SupportTicket>>> getTickets({int limit = 50, int offset = 0}) {
    return _graphQLService.query<List<SupportTicket>>(
      QueryOptions<List<SupportTicket>>(
        document: _ticketsDocument,
        variables: {'limit': limit, 'offset': offset},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (json) => [
          for (final t in json['tickets'] as List<dynamic>)
            SupportTicketDto.parse(t as Map<String, dynamic>, _language, withMessages: false),
        ],
      ),
    );
  }

  @override
  Future<Either<Failure, SupportTicket>> getTicket(String ticketId) async {
    final result = await _graphQLService.query<SupportTicket?>(
      QueryOptions<SupportTicket?>(
        document: _ticketDocument,
        variables: {'id': ticketId},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (json) {
          final ticket = json['ticket'];
          return ticket is Map<String, dynamic> ? SupportTicketDto.parse(ticket, _language, withMessages: true) : null;
        },
      ),
    );
    // A ticket outside the caller's scope is null: "not available".
    return result.flatMap((t) => t == null ? const Left(ServerFailure('Ticket not available.', code: 'ticket_not_found')) : Right(t));
  }

  @override
  Future<Either<Failure, SupportTicket>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
    TicketPriority priority = TicketPriority.normal,
    String? attachmentFileId,
    String? categoryCode,
  }) {
    // Only a general ticket can be opened from a subject and a message; a wallet
    // adjustment needs an agent, an action and an amount the form does not have.
    if (category != TicketCategory.general) {
      return Future.value(const Left(ServerFailure('This kind of ticket cannot be opened here.', code: unsupportedCode)));
    }
    return _graphQLService.mutate<SupportTicket>(
      MutationOptions<SupportTicket>(
        document: _openTicketDocument,
        variables: {
          'subject': subject,
          'description': message,
          'category': categoryCode ?? category.value,
          'priority': priority.value,
          'relatedRequestId': requestId,
          'attachmentFileId': attachmentFileId,
        },
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (json) => SupportTicketDto.parse(
          json['openGeneralTicket'] as Map<String, dynamic>,
          _language,
          withMessages: false,
        ),
      ),
    );
  }

  @override
  Future<Either<Failure, bool>> markTicketRead(String ticketId) {
    return _graphQLService.mutate<bool>(
      MutationOptions<bool>(
        document: _markTicketReadDocument,
        variables: {'ticketId': ticketId},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (json) => json['markTicketRead'] == true,
      ),
    );
  }

  @override
  Future<Either<Failure, TicketMessage>> replyToTicket({required String ticketId, required String message, String? attachmentFileId}) {
    return _graphQLService.mutate<TicketMessage>(
      MutationOptions<TicketMessage>(
        document: _replyDocument,
        variables: {'ticketId': ticketId, 'message': message, 'attachmentFileId': attachmentFileId},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (json) => TicketMessageDto.parse(json['replyTicket'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, NotificationsPage>> getNotifications({bool unreadOnly = false, int limit = 20, int offset = 0}) {
    return _graphQLService.query<NotificationsPage>(
      QueryOptions<NotificationsPage>(
        document: _notificationsDocument,
        variables: {'unreadOnly': unreadOnly, 'limit': limit, 'offset': offset},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (json) => InAppNotificationDto.parsePage(json['portalNotifications'] as Map<String, dynamic>, _language),
      ),
    );
  }

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() {
    return _graphQLService.query<int>(
      QueryOptions<int>(
        document: _unreadCountDocument,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (json) => ((json['portalNotifications'] as Map<String, dynamic>)['unreadCount'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) {
    return _graphQLService.mutate<bool>(
      MutationOptions<bool>(
        document: _markNotificationReadDocument,
        variables: {'notificationId': notificationId},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (json) => json['markNotificationRead'] == true,
      ),
    );
  }

  @override
  Future<Either<Failure, int>> markAllNotificationsRead() {
    return _graphQLService.mutate<int>(
      MutationOptions<int>(
        document: _markAllNotificationsReadDocument,
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (json) => (json['markAllNotificationsRead'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
