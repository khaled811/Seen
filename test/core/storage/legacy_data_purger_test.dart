import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/storage/legacy_data_purger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('removes legacy drafts and recent searches of every user, keeps preferences', () async {
    FlutterSecureStorage.setMockInitialValues({
      'booking_drafts_v1:u1': '[{"travelers":[]}]',
      'booking_drafts_v1:anonymous': '[]',
      'request_recent_searches_v1:u2': '["AHMED"]',
      'locale_code': 'ar',
      'auth_token': 'legacy-token',
    });

    // Built after the mock values: the plugin captures its platform instance on construction.
    const storage = FlutterSecureStorage();
    await LegacyDataPurger(storage).purge();

    final left = await storage.readAll();
    expect(left.keys, unorderedEquals(['locale_code', 'auth_token']));
  });

  test('removes the legacy session keys only when asked to', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 't', 'session_user': '{}', 'theme_mode': 'dark'});

    const storage = FlutterSecureStorage();
    await LegacyDataPurger(storage).purge(purgeSession: true);

    expect((await storage.readAll()).keys, ['theme_mode']);
  });

  test('is safe to run twice and on an empty store', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    await LegacyDataPurger(storage).purge();
    await LegacyDataPurger(storage).purge();
    expect(await storage.readAll(), isEmpty);
  });
}
