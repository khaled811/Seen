import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/repositories/recent_searches_store.dart';

/// Encrypted storage (Keystore / Keychain), one JSON list per agent.
class SecureRecentSearchesStore implements RecentSearchesStore {
  SecureRecentSearchesStore({required FlutterSecureStorage storage, required Future<String?> Function() userId})
      : _storage = storage,
        _userId = userId;

  final FlutterSecureStorage _storage;
  final Future<String?> Function() _userId;

  Future<String> _key() async => 'request_recent_searches_v1:${await _userId() ?? 'anonymous'}';

  @override
  Future<List<String>> read() async {
    try {
      final raw = await _storage.read(key: await _key());
      if (raw == null || raw.isEmpty) return const [];
      return [for (final e in jsonDecode(raw) as List<dynamic>) e as String];
    } catch (_) {
      // Unreadable history is only a convenience: start empty rather than fail.
      return const [];
    }
  }

  @override
  Future<List<String>> remember(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return read();
    final current = await read();
    final next = [
      clean,
      for (final q in current)
        if (q.toLowerCase() != clean.toLowerCase()) q,
    ].take(RecentSearchesStore.maxItems).toList();
    try {
      await _storage.write(key: await _key(), value: jsonEncode(next));
    } catch (_) {
      // Not being able to save a recent search must never break searching.
    }
    return next;
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: await _key());
    } catch (_) {
      // Same as above.
    }
  }
}
