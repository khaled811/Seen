import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/services/dua_audio_player.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/dua_audio_cubit.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/dua_player_cubit.dart';

import '../support/fakes.dart';

const _clip = 'assets/audio/duas/mock_silence.wav';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAudioPlayer player;
  late DuaPlayerCubit cubit;

  setUp(() {
    player = FakeAudioPlayer();
    cubit = DuaPlayerCubit(player);
  });

  tearDown(() => cubit.close());

  test('starts idle with no active dua', () {
    expect(cubit.state.activeId, isNull);
    expect(cubit.state.status, DuaAudioStatus.idle);
  });

  test('toggle plays the dua\'s clip', () async {
    await cubit.toggle('a', _clip);
    await _settle();
    expect(player.played, [_clip]);
    expect(cubit.state.activeId, 'a');
    expect(cubit.state.isActive('a'), isTrue);
    expect(cubit.state.isActive('b'), isFalse);
    expect(cubit.state.status, DuaAudioStatus.playing);
  });

  test('toggling the playing dua stops it', () async {
    await cubit.toggle('a', _clip);
    await _settle();
    await cubit.toggle('a', _clip);
    await _settle();
    expect(player.stops, 1);
    expect(cubit.state.activeId, isNull);
    expect(cubit.state.status, DuaAudioStatus.idle);
  });

  test('progress follows the player and is shown only while playing', () async {
    player.position(const Duration(seconds: 1));
    await _settle();
    expect(cubit.state.position, Duration.zero, reason: 'nothing playing yet');

    await cubit.toggle('a', _clip);
    await _settle();
    player.position(const Duration(milliseconds: 1500));
    await _settle();
    expect(cubit.state.position, const Duration(milliseconds: 1500));
  });

  test('a clip ending on its own returns to idle and clears progress', () async {
    await cubit.toggle('a', _clip);
    await _settle();
    player.position(const Duration(seconds: 2));
    await _settle();
    player.finish();
    await _settle();
    expect(cubit.state, const DuaPlayerState());
  });

  test('playing another dua replaces the first (one clip at a time)', () async {
    await cubit.toggle('a', _clip);
    await _settle();
    await cubit.toggle('b', _clip);
    await _settle();
    expect(cubit.state.activeId, 'b');
    expect(cubit.state.isActive('a'), isFalse);
    expect(player.played, hasLength(2));
  });

  test('a missing asset is an error for that dua', () async {
    await cubit.toggle('a', null);
    expect(cubit.state.activeId, 'a');
    expect(cubit.state.status, DuaAudioStatus.error);
    expect(player.played, isEmpty);
  });

  test('a player failure is an error, not a crash', () async {
    player.failPlay = true;
    await cubit.toggle('a', _clip);
    await _settle();
    expect(cubit.state.status, DuaAudioStatus.error);
    expect(cubit.state.isActive('a'), isFalse, reason: 'an error is not playing');
  });

  test('the error clears on the next attempt', () async {
    player.failPlay = true;
    await cubit.toggle('a', _clip);
    player.failPlay = false;
    await cubit.toggle('a', _clip);
    await _settle();
    expect(cubit.state.status, DuaAudioStatus.playing);
  });

  test('a stale idle while loading does not cancel the new clip', () async {
    await cubit.toggle('a', _clip);
    await _settle();
    // Starting b makes the player report the end of a first.
    player.finish();
    final next = cubit.toggle('b', _clip);
    await next;
    await _settle();
    expect(cubit.state.activeId, 'b');
  });

  test('closing stops the audio so it never outlives the screen', () async {
    await cubit.toggle('a', _clip);
    await _settle();
    final stopsBefore = player.stops;
    await cubit.close();
    expect(player.stops, greaterThan(stopsBefore));
    // Events after close must not throw.
    player.position(const Duration(seconds: 1));
    player.finish();
    await _settle();
  });

  test('DuaPlayback values map to states', () {
    expect(DuaPlayback.values, hasLength(3));
  });
}
