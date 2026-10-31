// Runs around every test file. Stubs the platform channels of plugins that the
// app starts at boot, so tests that pump `App` do not hit MissingPluginException.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/config/debug_fallbacks.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/failing_graphql_service.dart';
import 'support/failing_session_remote.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Existing screen tests rely on the demo data the DebugFallback decorators
  // supply when the real call fails. That dependency is now explicit, and the
  // "real call" is a transport that fails instantly instead of whatever the
  // sandbox HTTP stub does. Tests that need real failure behaviour set
  // `DebugFallbacks.testOverride = false` themselves.
  DebugFallbacks.testOverride = true;
  InjectionContainer.testDefaults = const InjectionOverrides(
    graphQLService: FailingGraphQLService(),
    sessionRemote: FailingSessionRemote(),
  );
  // In-memory preferences: an unmocked plugin channel answers on the real event
  // loop, which a widget test's fake clock never reaches (the install marker
  // read during sign-out would hang).
  SharedPreferences.setMockInitialValues({});
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  // connectivity_plus: always "wifi", and an event stream that never fires.
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => call.method == 'check' ? 'wifi' : null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
    (call) async => null,
  );
  // package_info_plus: read by AppStatusCubit after the status call returns.
  // With the instant FailingGraphQLService that call now finishes while the
  // test is still running, so the channel needs an answer.
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (call) async => call.method == 'getAll'
        ? <String, dynamic>{
            'appName': 'seen_booking',
            'packageName': 'net.seen.booking.test',
            'version': '1.0.0',
            'buildNumber': '1',
            'buildSignature': '',
          }
        : null,
  );
  await testMain();
}
