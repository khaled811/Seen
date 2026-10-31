import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/network/secure_cookie_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stores cookie entries under a prefix in the secure storage and reads them back', () async {
    FlutterSecureStorage.setMockInitialValues({'locale_code': 'ar'});
    const secure = FlutterSecureStorage();
    final storage = SecureCookieStorage(storage: secure);

    await storage.write('api.seen.test', '{"cookie":1}');

    expect(await storage.read('api.seen.test'), '{"cookie":1}');
    expect(
        (await secure.readAll()).keys, containsAll(['locale_code', '${SecureCookieStorage.keyPrefix}api.seen.test']));
    expect(await storage.read('missing'), isNull);
  });

  test('delete and deleteAll touch only cookie entries', () async {
    FlutterSecureStorage.setMockInitialValues({'locale_code': 'ar', 'theme_mode': 'dark'});
    const secure = FlutterSecureStorage();
    final storage = SecureCookieStorage(storage: secure);
    await storage.write('a', '1');
    await storage.write('b', '2');
    await storage.write('.index', '["a","b"]');

    await storage.delete('a');
    expect(await storage.read('a'), isNull);
    expect(await storage.read('b'), '2');

    // Even an entry the jar forgot about (lost index) is removed.
    await storage.deleteAll(['.index']);
    expect((await secure.readAll()).keys, unorderedEquals(['locale_code', 'theme_mode']));
  });

  test('the first-use hook runs once per init and a failing hook does not stop the jar', () async {
    FlutterSecureStorage.setMockInitialValues({});
    var runs = 0;
    final ok = SecureCookieStorage(storage: const FlutterSecureStorage(), beforeFirstUse: () async => runs++);
    await ok.init(false, false);
    expect(runs, 1);

    final broken = SecureCookieStorage(
      storage: const FlutterSecureStorage(),
      beforeFirstUse: () async => throw StateError('prefs unavailable'),
    );
    await expectLater(broken.init(false, false), completes);
  });

  test('wipe removes every cookie entry and leaves everything else', () async {
    FlutterSecureStorage.setMockInitialValues({
      '${SecureCookieStorage.keyPrefix}api.seen.test': 'x',
      '${SecureCookieStorage.keyPrefix}.index': '[]',
      'locale_code': 'ar',
    });
    const secure = FlutterSecureStorage();

    await SecureCookieStorage.wipe(secure);

    expect((await secure.readAll()).keys, ['locale_code']);
  });
}
