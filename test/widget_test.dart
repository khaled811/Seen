// Basic smoke test verifying the app boots, restores an (absent) session,
// and lands on the login screen with its localized title.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seen_booking/app.dart';
import 'package:seen_booking/core/di/injection_container.dart';

// `flutter_secure_storage` has no test-host implementation; a real call
// hangs indefinitely under `flutter test` (no engine to answer it) rather
// than throwing, so it must be stubbed for AuthBloc's session-restore read
// to resolve at all.
const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
    InjectionContainer.instance.init();
  });

  testWidgets('App boots and shows the login screen', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
