import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers that the person has seen the "before you show this value" notice (design/gaps
/// PRIV-03). The server has no such flag, so it is kept on this device, per install. It holds
/// no personal data. A storage failure just shows the notice again.
class RevealIntroStore {
  RevealIntroStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'reveal_intro_seen';

  final FlutterSecureStorage _storage;

  Future<bool> seen() async {
    try {
      return await _storage.read(key: _key) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      await _storage.write(key: _key, value: 'true');
    } catch (_) {
      // Shown again next time; nothing else depends on it.
    }
  }
}
