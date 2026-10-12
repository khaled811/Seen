import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/dua_audio_cubit.dart';

import '../support/fakes.dart';

void main() {
  late FakeAudioPlayer player;
  late DuaAudioCubit cubit;

  setUp(() {
    player = FakeAudioPlayer();
    cubit = DuaAudioCubit(player);
  });

  tearDown(() => cubit.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('toggle plays the asset and reports playing', () async {
    await cubit.toggle('a.wav');
    await settle();
    expect(player.played, ['a.wav']);
    expect(cubit.state.status, DuaAudioStatus.playing);
  });

  test('toggling again stops it', () async {
    await cubit.toggle('a.wav');
    await settle();
    await cubit.toggle('a.wav');
    await settle();
    expect(player.stops, 1);
    expect(cubit.state.status, DuaAudioStatus.idle);
  });

  test('a clip finishing by itself returns to idle', () async {
    await cubit.toggle('a.wav');
    await settle();
    player.finish();
    await settle();
    expect(cubit.state.status, DuaAudioStatus.idle);
  });

  test('a missing/unplayable asset yields error, then can be retried', () async {
    player.failPlay = true;
    await cubit.toggle('missing.wav');
    expect(cubit.state.status, DuaAudioStatus.error);
    player.failPlay = false;
    await cubit.toggle('a.wav');
    await settle();
    expect(cubit.state.status, DuaAudioStatus.playing);
  });

  test('a dua without audio is an error, not a crash', () async {
    await cubit.toggle(null);
    expect(cubit.state.status, DuaAudioStatus.error);
    expect(player.played, isEmpty);
  });

  test('closing the cubit stops playback so audio never outlives the screen',
      () async {
    await cubit.toggle('a.wav');
    await settle();
    final stopsBefore = player.stops;
    await cubit.close();
    expect(player.stops, greaterThan(stopsBefore));
  });
}
