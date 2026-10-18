import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_preferences_repository.dart';

const _wire = {
  NotificationCategory.statusUpdates: 'status_updates',
  NotificationCategory.documents: 'documents',
  NotificationCategory.wallet: 'wallet',
  NotificationCategory.subAgents: 'sub_agents',
  NotificationCategory.support: 'support',
  NotificationCategory.promotions: 'promotions',
};

NotificationPreferences _parse(Object? json) {
  final m = json as Map<String, dynamic>;
  final cats = <NotificationCategory, bool>{...NotificationPreferences.defaults.categories};
  for (final c in (m['categories'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>()) {
    final key = _wire.entries.where((e) => e.value == c['key']).map((e) => e.key).firstOrNull;
    if (key != null) {
      cats[key] = c['enabled'] == true;
    }
  }
  final q = m['quietHours'] as Map<String, dynamic>?;
  final d = NotificationPreferences.defaults.quietHours;
  return NotificationPreferences(
    categories: cats,
    quietHours: q == null
        ? d
        : QuietHours(
            enabled: q['enabled'] == true,
            startMinutes: (q['startMinutes'] as num?)?.toInt() ?? d.startMinutes,
            endMinutes: (q['endMinutes'] as num?)?.toInt() ?? d.endMinutes,
          ),
  );
}

/// Raw GraphQL access to the notification preferences.
///
/// TODO(backend-contract): placeholder schema (`notificationPreferences`,
/// `saveNotificationPreferences`); see docs/BACKEND_MIGRATION_GAPS.md section 40.
class NotificationPreferencesRemoteDataSource implements NotificationPreferencesRepository {
  NotificationPreferencesRemoteDataSource({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static const _fields = 'categories { key enabled } quietHours { enabled startMinutes endMinutes }';

  static final _getDoc = gql('query NotificationPreferences { notificationPreferences { $_fields } }');

  static final _saveDoc = gql('''
    mutation SaveNotificationPreferences(\$categories: [NotificationCategoryInput!]!, \$quiet: QuietHoursInput!) {
      saveNotificationPreferences(categories: \$categories, quietHours: \$quiet) { $_fields }
    }
  ''');

  @override
  Future<Either<Failure, NotificationPreferences>> get() => _graphQL.query<NotificationPreferences>(
        QueryOptions<NotificationPreferences>(
          document: _getDoc,
          fetchPolicy: FetchPolicy.networkOnly,
          parserFn: (j) => _parse(j['notificationPreferences']),
        ),
      );

  @override
  Future<Either<Failure, NotificationPreferences>> save(NotificationPreferences p) =>
      _graphQL.mutate<NotificationPreferences>(
        MutationOptions<NotificationPreferences>(
          document: _saveDoc,
          variables: {
            'categories': [
              for (final e in _wire.entries) {'key': e.value, 'enabled': p.isOn(e.key)},
            ],
            'quiet': {
              'enabled': p.quietHours.enabled,
              'startMinutes': p.quietHours.startMinutes,
              'endMinutes': p.quietHours.endMinutes,
            },
          },
          parserFn: (j) => _parse(j['saveNotificationPreferences']),
        ),
      );
}

/// DEBUG ONLY: when a real call fails in a debug build, keeps the preferences in memory
/// so the screen can be used without a backend. Release builds drop the branch
/// (`kDebugMode` is a compile-time constant). Nothing is persisted.
class DebugFallbackNotificationPreferencesRepository implements NotificationPreferencesRepository {
  DebugFallbackNotificationPreferencesRepository(this._real);

  final NotificationPreferencesRepository _real;
  NotificationPreferences _memory = NotificationPreferences.defaults;

  @override
  Future<Either<Failure, NotificationPreferences>> get() async {
    final r = await _real.get();
    if (kDebugMode && r.isLeft()) {
      return Right(_memory);
    }
    return r;
  }

  @override
  Future<Either<Failure, NotificationPreferences>> save(NotificationPreferences p) async {
    final r = await _real.save(p);
    if (kDebugMode && r.isLeft()) {
      _memory = p;
      return Right(p);
    }
    return r;
  }
}
