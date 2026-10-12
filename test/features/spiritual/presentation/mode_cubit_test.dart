import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/app_mode.dart';
import 'package:seen_booking/features/spiritual/domain/repositories/mode_repository.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/mode_cubit.dart';

class FakeModeRepository implements ModeRepository {
  FakeModeRepository([this.stored = AppMode.agent]);

  AppMode stored;
  int saves = 0;

  @override
  Future<AppMode> load() async => stored;

  @override
  Future<void> save(AppMode mode) async {
    saves++;
    stored = mode;
  }
}

void main() {
  test('starts unrestored in agent mode', () async {
    final cubit = ModeCubit(FakeModeRepository());
    expect(cubit.state, const ModeState());
    await cubit.close();
  });

  test('restore adopts the persisted mode', () async {
    final cubit = ModeCubit(FakeModeRepository(AppMode.manasik));
    await cubit.restore();
    expect(cubit.state.mode, AppMode.manasik);
    expect(cubit.state.restored, isTrue);
    await cubit.close();
  });

  test('toggle flips the mode and persists it', () async {
    final repo = FakeModeRepository();
    final cubit = ModeCubit(repo);
    await cubit.restore();
    cubit.toggle();
    expect(cubit.state.mode, AppMode.manasik);
    expect(repo.stored, AppMode.manasik);
    cubit.toggle();
    expect(cubit.state.mode, AppMode.agent);
    expect(repo.saves, 2);
    await cubit.close();
  });

  test('selecting the current mode does not save again', () async {
    final repo = FakeModeRepository();
    final cubit = ModeCubit(repo);
    await cubit.restore();
    cubit.select(AppMode.agent);
    expect(repo.saves, 0);
    await cubit.close();
  });

  test('ignores toggles before the mode has been restored', () async {
    final repo = FakeModeRepository();
    final cubit = ModeCubit(repo);
    cubit.toggle();
    expect(cubit.state.mode, AppMode.agent);
    expect(repo.saves, 0);
    await cubit.close();
  });

  test('manasik tab selection is bounds-checked', () async {
    final cubit = ModeCubit(FakeModeRepository());
    await cubit.restore();
    cubit.selectManasikTab(2);
    expect(cubit.state.manasikTab, 2);
    cubit.selectManasikTab(9);
    cubit.selectManasikTab(-1);
    expect(cubit.state.manasikTab, 2);
    await cubit.close();
  });

  test('restore finishing after close does not emit', () async {
    final cubit = ModeCubit(FakeModeRepository(AppMode.manasik));
    final pending = cubit.restore();
    await cubit.close();
    await pending;
    expect(cubit.state.restored, isFalse);
  });
}
