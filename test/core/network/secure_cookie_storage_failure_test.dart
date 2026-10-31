// No secure-storage mock is installed in this file on purpose: every call
// throws MissingPluginException, like a keystore that cannot be read.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/network/secure_cookie_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final storage = SecureCookieStorage(storage: const FlutterSecureStorage());

  test('an unreadable store reads as "no cookie"', () async {
    expect(await storage.read('api.seen.test'), isNull);
  });

  test('a failing write, delete or wipe never throws', () async {
    await expectLater(storage.write('k', 'v'), completes);
    await expectLater(storage.delete('k'), completes);
    await expectLater(storage.deleteAll(['k']), completes);
    await expectLater(SecureCookieStorage.wipe(const FlutterSecureStorage()), completes);
  });
}
