// What ends with a session: the branch the previous person was viewing and their
// recent searches must not carry over to the next account.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/state/branch_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ending the session clears the branch scope and the recent searches', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    final container = InjectionContainer.instance..init();
    BranchScope.shared.value = 'branch-of-the-previous-agency';
    await container.recentSearchesStore.remember('SB-1001');

    await container.sessionManager.endSession();

    expect(BranchScope.shared.value, isNull);
    expect(await container.recentSearchesStore.read(), isEmpty);
  });
}
