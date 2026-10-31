import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/storage/install_marker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('is true exactly once per install', () async {
    SharedPreferences.setMockInitialValues({});
    final marker = InstallMarker();

    expect(await marker.isFirstRunThenMark(), isTrue);
    expect(await marker.isFirstRunThenMark(), isFalse);
    expect(await InstallMarker().isFirstRunThenMark(), isFalse, reason: 'a later launch');
  });

  test('an existing install is not treated as fresh', () async {
    SharedPreferences.setMockInitialValues({'install_marker_v1': true});

    expect(await InstallMarker().isFirstRunThenMark(), isFalse);
  });
}
