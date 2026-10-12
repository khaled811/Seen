import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../models/in_app_notification_dto.dart';
import '../models/support_ticket_dto.dart';

/// Raw GraphQL access for the support feature. Returns DTOs, never entities.
///
/// TODO(backend-contract): documents below encode a placeholder schema
/// (query/mutation names, argument names, response fields). Update once the
/// real Seen Booking GraphQL schema is confirmed — see the matching TODOs
/// in the DTO files.
abstract interface class SupportRemoteDataSource {
  Future<Either<Failure, List<SupportTicketDto>>> getTickets();

  Future<Either<Failure, SupportTicketDto>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
  });

  Future<Either<Failure, SupportTicketDto>> replyToTicket({
    required String ticketId,
    required String message,
  });

  Future<Either<Failure, List<InAppNotificationDto>>> getNotifications();

  Future<Either<Failure, bool>> markNotificationRead(String notificationId);

  Future<Either<Failure, bool>> markAllNotificationsRead();
}

class SupportRemoteDataSourceImpl implements SupportRemoteDataSource {
  SupportRemoteDataSourceImpl({required GraphQLService graphQLService})
      : _graphQLService = graphQLService;

  final GraphQLService _graphQLService;

  static const _ticketFields = r'''
    id
    referenceId
    category
    priority
    subject
    requestId
    status
    createdAt
    messages { id authorName isSupportReply body sentAt }
  ''';

  static final _ticketsDocument = gql('''
    query SupportTickets {
      supportTickets {
        $_ticketFields
      }
    }
  ''');

  static final _createTicketDocument = gql('''
    mutation CreateTicket(
      \$category: String!
      \$subject: String!
      \$message: String!
      \$requestId: ID
    ) {
      createTicket(
        category: \$category
        subject: \$subject
        message: \$message
        requestId: \$requestId
      ) {
        $_ticketFields
      }
    }
  ''');

  static final _replyToTicketDocument = gql('''
    mutation ReplyToTicket(\$ticketId: ID!, \$message: String!) {
      replyToTicket(ticketId: \$ticketId, message: \$message) {
        $_ticketFields
      }
    }
  ''');

  static final _notificationsDocument = gql(r'''
    query Notifications {
      notifications {
        id
        type
        title
        body
        createdAt
        isRead
        relatedRequestId
      }
    }
  ''');

  static final _markNotificationReadDocument = gql(r'''
    mutation MarkNotificationRead($notificationId: ID!) {
      markNotificationRead(notificationId: $notificationId) {
        success
      }
    }
  ''');

  static final _markAllNotificationsReadDocument = gql(r'''
    mutation MarkAllNotificationsRead {
      markAllNotificationsRead {
        success
      }
    }
  ''');

  @override
  Future<Either<Failure, List<SupportTicketDto>>> getTickets() {
    return _graphQLService.query<List<SupportTicketDto>>(
      QueryOptions<List<SupportTicketDto>>(
        document: _ticketsDocument,
        parserFn: (json) => (json['supportTickets'] as List<dynamic>)
            .map((e) => SupportTicketDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  @override
  Future<Either<Failure, SupportTicketDto>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
  }) {
    return _graphQLService.mutate<SupportTicketDto>(
      MutationOptions<SupportTicketDto>(
        document: _createTicketDocument,
        variables: {
          'category': category.value,
          'subject': subject,
          'message': message,
          'requestId': requestId,
        },
        parserFn: (json) =>
            SupportTicketDto.fromJson(json['createTicket'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, SupportTicketDto>> replyToTicket({
    required String ticketId,
    required String message,
  }) {
    return _graphQLService.mutate<SupportTicketDto>(
      MutationOptions<SupportTicketDto>(
        document: _replyToTicketDocument,
        variables: {'ticketId': ticketId, 'message': message},
        parserFn: (json) =>
            SupportTicketDto.fromJson(json['replyToTicket'] as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, List<InAppNotificationDto>>> getNotifications() {
    return _graphQLService.query<List<InAppNotificationDto>>(
      QueryOptions<List<InAppNotificationDto>>(
        document: _notificationsDocument,
        parserFn: (json) => (json['notifications'] as List<dynamic>)
            .map((e) => InAppNotificationDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) {
    return _graphQLService.mutate<bool>(
      MutationOptions<bool>(
        document: _markNotificationReadDocument,
        variables: {'notificationId': notificationId},
        parserFn: (json) =>
            (json['markNotificationRead'] as Map<String, dynamic>?)?['success']
                as bool? ??
            true,
      ),
    );
  }

  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() {
    return _graphQLService.mutate<bool>(
      MutationOptions<bool>(
        document: _markAllNotificationsReadDocument,
        parserFn: (json) =>
            (json['markAllNotificationsRead'] as Map<String, dynamic>?)?['success']
                as bool? ??
            true,
      ),
    );
  }
}
