import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/data/repositories/mode_repository_impl.dart';
import 'package:seen_booking/features/spiritual/domain/entities/app_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to agent when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await ModeRepositoryImpl().load(), AppMode.agent);
  });

  test('round-trips the saved mode', () async {
    SharedPreferences.setMockInitialValues({});
    await ModeRepositoryImpl().save(AppMode.manasik);
    expect(await ModeRepositoryImpl().load(), AppMode.manasik);
  });

  test('an unknown stored value falls back to agent', () async {
    SharedPreferences.setMockInitialValues(
      {ModeRepositoryImpl.storageKey: 'bogus'},
    );
    expect(await ModeRepositoryImpl().load(), AppMode.agent);
  });

  test('a failing store falls back instead of throwing', () async {
    final failing = Future<SharedPreferences>.error(StateError('no disk'));
    final repo = ModeRepositoryImpl(preferences: failing);
    expect(await repo.load(), AppMode.agent);
    await repo.save(AppMode.manasik); // must not throw
  });
}
