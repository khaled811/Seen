import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/network/api_client.dart';
import 'package:seen_booking/core/network/auth_session_controller.dart';
import 'package:seen_booking/core/network/refresh_coordinator.dart';
import 'package:seen_booking/core/network/session_manager.dart';
import 'package:seen_booking/core/network/strict_cookie_jar.dart';

import '../../support/fake_api_server.dart';

final _uri = Uri.parse('https://api.seen.test/graphql/');

class _Rig {
  _Rig({Duration idleWait = const Duration(seconds: 3), Duration logoutTimeout = const Duration(seconds: 3)}) {
    server = FakeServerAdapter(backend.call);
    jar = StrictPersistCookieJar(storage: MemoryCookieStorage());
    api = ApiClient.create(cookieJar: jar, session: AuthSessionController(), graphqlUri: _uri, adapter: server);
    manager = SessionManager(
      tokens: api.tokens,
      coordinator: api.coordinator,
      remote: api.sessionRemote,
      cookieJar: jar,
      clearHttpCache: () async => cacheCleared = true,
      cleanups: [() async => cleanups.add('a'), () async => throw StateError('x'), () async => cleanups.add('b')],
      idleWait: idleWait,
      serverLogoutTimeout: logoutTimeout,
    );
  }

  final backend = FakeBackend();
  late final FakeServerAdapter server;
  late final StrictPersistCookieJar jar;
  late final ApiClient api;
  late final SessionManager manager;
  bool cacheCleared = false;
  final cleanups = <String>[];

  Future<void> signIn() async {
    await api
        .graphqlHttpClient()
        .post(_uri, headers: {'content-type': 'application/json'}, body: '{"query":"mutation Login { login }"}');
    manager.startSession(backend.validToken);
  }
}

void main() {
  test('restoreAccessToken turns the stored cookie into an access token', () async {
    final rig = _Rig();
    await rig.signIn();
    rig.api.tokens.clear(); // a fresh launch: cookie in the jar, nothing in memory

    expect(await rig.manager.restoreAccessToken(), RefreshStatus.refreshed);
    expect(rig.api.tokens.token, rig.backend.validToken);
  });

  test('restoreAccessToken with no cookie says the session is over', () async {
    final rig = _Rig();

    expect(await rig.manager.restoreAccessToken(), RefreshStatus.sessionEnded);
    expect(rig.api.tokens.hasToken, isFalse);
  });

  test('endSession clears the token, asks the server, wipes cookie, cache and per-user data', () async {
    final rig = _Rig();
    await rig.signIn();

    await rig.manager.endSession();

    expect(rig.api.tokens.hasToken, isFalse);
    expect(rig.backend.logoutCalls, 1);
    expect(await rig.jar.loadForRequest(_uri), isEmpty);
    expect(rig.cacheCleared, isTrue);
    expect(rig.cleanups, ['a', 'b'], reason: 'a failing cleanup must not stop the next one');
  });

  test('endSession still wipes everything when the server cannot be reached', () async {
    final rig = _Rig();
    await rig.signIn();
    final real = rig.backend.call;
    rig.server.responder = (r) => r.operation == 'Logout'
        ? throw DioException.connectionError(requestOptions: r.options, reason: 'offline')
        : real(r);

    await rig.manager.endSession();

    expect(await rig.jar.loadForRequest(_uri), isEmpty);
    expect(rig.api.tokens.hasToken, isFalse);
    expect(rig.cacheCleared, isTrue);
  });

  test('endSession does not hang on a server that never answers', () async {
    final rig = _Rig(logoutTimeout: const Duration(milliseconds: 50));
    await rig.signIn();
    final real = rig.backend.call;
    rig.server.responder = (r) => r.operation == 'Logout' ? Completer<ResponseBody>().future : real(r);

    await rig.manager.endSession().timeout(const Duration(seconds: 2));

    expect(await rig.jar.loadForRequest(_uri), isEmpty);
  });

  test('endSession waits for a refresh already running before it logs out', () async {
    final rig = _Rig();
    await rig.signIn();
    final gate = Completer<void>();
    rig.backend.refreshGate = () => gate.future;
    final refresh = rig.api.coordinator.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final ending = rig.manager.endSession();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(rig.backend.logoutCalls, 0, reason: 'logout must use the rotated cookie, so it waits');

    gate.complete();
    await refresh;
    await ending;

    expect(rig.backend.logoutCalls, 1);
    expect(rig.api.tokens.hasToken, isFalse, reason: 'the late refresh result was discarded');
    expect(await rig.jar.loadForRequest(_uri), isEmpty);
  });
}
