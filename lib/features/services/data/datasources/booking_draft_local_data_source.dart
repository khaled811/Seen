import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/booking_draft.dart';
import '../../domain/entities/service_definition.dart';
import '../../domain/entities/traveler_info.dart';

/// Where the drafts of one agent live. Drafts hold passport data, so the
/// implementation keeps them in the platform's encrypted storage, never in plain
/// preferences.
abstract interface class BookingDraftLocalDataSource {
  Future<List<BookingDraft>> read();

  Future<void> write(List<BookingDraft> drafts);
}

/// Encrypted storage (Keystore / Keychain), one JSON document per agent.
class SecureBookingDraftLocalDataSource implements BookingDraftLocalDataSource {
  SecureBookingDraftLocalDataSource({required FlutterSecureStorage storage, required Future<String?> Function() userId})
      : _storage = storage,
        _userId = userId;

  final FlutterSecureStorage _storage;
  final Future<String?> Function() _userId;

  Future<String> _key() async => 'booking_drafts_v1:${await _userId() ?? 'anonymous'}';

  @override
  Future<List<BookingDraft>> read() async {
    final raw = await _storage.read(key: await _key());
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List<dynamic>) BookingDraftJson.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      // A document this version cannot read is dropped rather than crashing the list.
      return const [];
    }
  }

  @override
  Future<void> write(List<BookingDraft> drafts) async {
    final key = await _key();
    if (drafts.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: jsonEncode([for (final d in drafts) BookingDraftJson.toJson(d)]));
    }
  }
}

/// JSON shape of a draft. Field values keep their type (`String` / `DateTime` /
/// number / bool) through a one-letter tag, matching the dynamic-form engine.
abstract final class BookingDraftJson {
  static Map<String, Object?> toJson(BookingDraft d) => {
        'id': d.id,
        'serviceId': d.serviceId,
        'serviceName': d.serviceName,
        'category': d.category.value,
        'updatedAt': d.updatedAt.toIso8601String(),
        'hospitalId': d.hospitalId,
        'hospitalName': d.hospitalName,
        'travelers': [
          for (final t in d.travelers)
            {
              'id': t.id,
              'values': {for (final e in t.fieldValues.entries) e.key: _encode(e.value)},
            },
        ],
      };

  static BookingDraft fromJson(Map<String, dynamic> json) => BookingDraft(
        id: json['id'] as String,
        serviceId: json['serviceId'] as String,
        serviceName: json['serviceName'] as String,
        category: ServiceCategory.fromValue(json['category'] as String?),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        hospitalId: json['hospitalId'] as String?,
        hospitalName: json['hospitalName'] as String?,
        travelers: [
          for (final t in json['travelers'] as List<dynamic>)
            TravelerInfo(
              id: (t as Map<String, dynamic>)['id'] as String,
              fieldValues: {
                for (final e in (t['values'] as Map<String, dynamic>).entries) e.key: _decode(e.value),
              },
            ),
        ],
      );

  static Object? _encode(Object? v) => switch (v) {
        null => null,
        DateTime() => {'t': 'd', 'v': v.toIso8601String()},
        bool() => {'t': 'b', 'v': v},
        num() => {'t': 'n', 'v': v},
        _ => {'t': 's', 'v': v.toString()},
      };

  static Object? _decode(Object? j) {
    if (j is! Map) return null;
    final v = j['v'];
    return switch (j['t']) {
      'd' => DateTime.parse(v as String),
      'b' => v as bool,
      'n' => v as num,
      _ => v as String?,
    };
  }
}
