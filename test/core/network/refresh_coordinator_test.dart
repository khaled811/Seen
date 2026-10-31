import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/network/access_token_store.dart';
import 'package:seen_booking/core/network/refresh_coordinator.dart';
import 'package:seen_booking/core/network/session_remote_data_source.dart';

class _Remote implements SessionRemoteDataSource {
  _Remote(this.answer);

  Future<RefreshResponse> Function() answer;
  int calls = 0;

  @override
  Future<RefreshResponse> refresh() {
    calls++;
    return answer();
  }

  @override
  Future<void> logout() async {}
}

void main() {
  test('callers that overlap share one call and one result', () async {
    final gate = Completer<RefreshResponse>();
    final remote = _Remote(() => gate.future);
    final tokens = AccessTokenStore();
    final coordinator = RefreshCoordinator(tokens: tokens, remote: remote);

    final all = [for (var i = 0; i < 5; i++) coordinator.refresh()];
    gate.complete(const RefreshSucceeded('new'));

    expect(await Future.wait(all), everyElement(RefreshStatus.refreshed));
    expect(remote.calls, 1);
    expect(tokens.token, 'new');
  });

  test('a later refresh is a new call', () async {
    final remote = _Remote(() async => const RefreshSucceeded('t'));
    final coordinator = RefreshCoordinator(tokens: AccessTokenStore(), remote: remote);

    await coordinator.refresh();
    await coordinator.refresh();

    expect(remote.calls, 2);
  });

  test('a rejection ends the session and clears the token', () async {
    final tokens = AccessTokenStore()..set('old');
    final coordinator = RefreshCoordinator(
      tokens: tokens,
      remote: _Remote(() async => const RefreshRejected('session_expired')),
    );

    expect(await coordinator.refresh(), RefreshStatus.sessionEnded);
    expect(tokens.hasToken, isFalse);
  });

  test('an unavailable answer or a throw changes nothing and is not retried', () async {
    final tokens = AccessTokenStore()..set('old');
    final unavailable = _Remote(() async => const RefreshUnavailable());
    final throwing = _Remote(() async => throw StateError('x'));

    expect(await RefreshCoordinator(tokens: tokens, remote: unavailable).refresh(), RefreshStatus.failed);
    expect(await RefreshCoordinator(tokens: tokens, remote: throwing).refresh(), RefreshStatus.failed);

    expect(tokens.token, 'old');
    expect(unavailable.calls, 1);
    expect(throwing.calls, 1);
  });

  test('an answer that arrives after a sign-out is discarded', () async {
    final gate = Completer<RefreshResponse>();
    final tokens = AccessTokenStore()..set('old');
    final coordinator = RefreshCoordinator(tokens: tokens, remote: _Remote(() => gate.future));

    final pending = coordinator.refresh();
    tokens.clear();
    gate.complete(const RefreshSucceeded('late'));

    expect(await pending, RefreshStatus.failed);
    expect(tokens.hasToken, isFalse);
  });

  test('idle completes at once when nothing runs and after the running refresh otherwise', () async {
    final gate = Completer<RefreshResponse>();
    final coordinator = RefreshCoordinator(tokens: AccessTokenStore(), remote: _Remote(() => gate.future));
    await coordinator.idle;

    var idle = false;
    final pending = coordinator.refresh();
    unawaited(coordinator.idle.then((_) => idle = true));
    await Future<void>.delayed(Duration.zero);
    expect(idle, isFalse);

    gate.complete(const RefreshUnavailable());
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(idle, isTrue);
  });
}
