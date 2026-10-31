// The transport and session foundation, against a fake backend that rotates the
// refresh cookie and rejects reuse. No network; deterministic.

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:seen_booking/core/network/access_token_store.dart';
import 'package:seen_booking/core/network/api_client.dart';
import 'package:seen_booking/core/network/auth_session_controller.dart';
import 'package:seen_booking/core/network/refresh_coordinator.dart';
import 'package:seen_booking/core/network/strict_cookie_jar.dart';

import '../../support/fake_api_server.dart';

final _uri = Uri.parse('https://api.seen.test/graphql/');

class _Rig {
  _Rig({MemoryCookieStorage? storage, DateTime Function()? clock, FakeBackend? backend})
      : backend = backend ?? FakeBackend(),
        storage = storage ?? MemoryCookieStorage(),
        now = clock {
    server = FakeServerAdapter(this.backend.call);
    jar = StrictPersistCookieJar(storage: this.storage);
    tokens = AccessTokenStore(clock: now ?? DateTime.now);
    controller = AuthSessionController();
    sub = controller.events.listen(events.add);
    api = ApiClient.create(
      cookieJar: jar,
      session: controller,
      graphqlUri: _uri,
      tokens: tokens,
      adapter: server,
    );
    client = api.graphqlHttpClient();
  }

  final FakeBackend backend;
  final MemoryCookieStorage storage;
  final DateTime Function()? now;
  late final FakeServerAdapter server;
  late final StrictPersistCookieJar jar;
  late final AccessTokenStore tokens;
  late final AuthSessionController controller;
  late final StreamSubscription<AuthSessionEvent> sub;
  late final ApiClient api;
  late final http.Client client;
  final events = <AuthSessionEvent>[];

  Future<http.Response> call(String operation) => client.post(
        _uri,
        headers: {'content-type': 'application/json'},
        body: '{"query":"query $operation { x }"}',
      );

  /// Signs in through the stack so the cookie lands in the jar.
  Future<void> signIn() async {
    await client.post(_uri,
        headers: {'content-type': 'application/json'}, body: '{"query":"mutation Login { login }"}');
    tokens.set(backend.validToken);
  }

  Future<void> dispose() => sub.cancel();
}

void main() {
  group('access token header', () {
    test('is attached when a token is held and absent when not', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);

      await rig.call('Public');
      rig.tokens.set('token-0');
      await rig.call('Wallet');

      expect(rig.server.requests[0].authorization, isNull);
      expect(rig.server.requests[1].authorization, 'Bearer token-0');
    });
  });

  group('expired access token', () {
    test('one refresh, then the request is replayed once with the new token', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.backend.expireAccessToken();

      final response = await rig.call('Wallet');

      expect(response.body, contains('"ok":true'));
      expect(rig.backend.refreshCalls, 1);
      final wallet = rig.server.where('Wallet');
      expect(wallet, hasLength(2));
      expect(wallet.first.authorization, isNot(wallet.last.authorization));
      expect(wallet.last.authorization, 'Bearer ${rig.backend.validToken}');
      expect(rig.tokens.token, rig.backend.validToken);
      expect(rig.events, isEmpty);
    });

    test('the refresh itself carries the cookie and no access token', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      final cookieBefore = rig.backend.validRefresh;
      rig.backend.expireAccessToken();

      await rig.call('Wallet');

      final refresh = rig.server.where('Refresh').single;
      expect(refresh.cookie, contains('sb_refresh=$cookieBefore'));
      expect(refresh.authorization, isNull);
    });

    test('five requests that fail together share one refresh and each is replayed once', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      final gate = Completer<void>();
      rig.backend.refreshGate = () => gate.future;
      rig.backend.expireAccessToken();

      final calls = [for (var i = 0; i < 5; i++) rig.call('Op$i')];
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      final responses = await Future.wait(calls);

      expect(responses.map((r) => r.body.contains('"ok":true')), everyElement(isTrue));
      expect(rig.backend.refreshCalls, 1);
      for (var i = 0; i < 5; i++) {
        expect(rig.server.where('Op$i'), hasLength(2), reason: 'Op$i: original + one replay');
      }
    });

    test('a replay that is rejected again does not refresh a second time', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.backend.expireAccessToken();
      // Whatever token is sent, the server keeps saying not_authenticated.
      final real = rig.backend.call;
      rig.server.responder = (r) => r.operation == 'Refresh' ? real(r) : gql(gqlError('not_authenticated'));

      final response = await rig.call('Wallet');

      expect(response.body, contains('not_authenticated'));
      expect(rig.backend.refreshCalls, 1);
      expect(rig.server.where('Wallet'), hasLength(2));
    });

    test('a request sent without a token is never "refreshed"', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);

      final response = await rig.call('Wallet');

      expect(response.body, contains('not_authenticated'));
      expect(rig.backend.refreshCalls, 0);
    });
  });

  group('refresh failures', () {
    test('a rejected refresh ends the session once and leaves the original error', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.backend
        ..expireAccessToken()
        ..sessionAlive = false;

      final response = await rig.call('Wallet');
      await Future<void>.delayed(Duration.zero);

      expect(response.body, contains('not_authenticated'));
      expect(rig.tokens.hasToken, isFalse);
      expect(rig.events, [AuthSessionEvent.unauthenticated]);
      expect(rig.backend.refreshCalls, 1);
    });

    test('no_refresh_session (cookie missing) also ends the session', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      rig.tokens.set('token-0'); // a token but no cookie: e.g. cookie expired
      rig.backend.expireAccessToken();

      await rig.call('Wallet');
      await Future<void>.delayed(Duration.zero);

      expect(rig.tokens.hasToken, isFalse);
      expect(rig.events, [AuthSessionEvent.unauthenticated]);
    });

    test('a refresh that times out is not retried and does not end the session', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.backend.expireAccessToken();
      final real = rig.backend.call;
      rig.server.responder = (r) {
        if (r.operation == 'Refresh') {
          throw DioException.receiveTimeout(timeout: const Duration(seconds: 1), requestOptions: r.options);
        }
        return real(r);
      };

      await expectLater(rig.call('Wallet'), throwsA(isA<SocketException>()));

      expect(rig.server.where('Refresh'), hasLength(1), reason: 'an ambiguous refresh is never replayed');
      expect(rig.server.where('Wallet'), hasLength(1));
      expect(rig.tokens.hasToken, isTrue);
      expect(rig.events, isEmpty);
    });

    test('a refresh answered with another error code does not end the session', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      rig.backend.expireAccessToken();
      final real = rig.backend.call;
      rig.server.responder = (r) => r.operation == 'Refresh' ? gql(gqlError('too_many_attempts')) : real(r);

      await expectLater(rig.call('Wallet'), throwsA(isA<SocketException>()));

      expect(rig.tokens.hasToken, isTrue);
      expect(rig.events, isEmpty);
    });

    test('signing out while a refresh is in flight discards its result', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      final gate = Completer<void>();
      rig.backend.refreshGate = () => gate.future;
      rig.backend.expireAccessToken();

      final pending = rig.call('Wallet');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      rig.tokens.clear(); // sign-out
      gate.complete();
      await pending.catchError((_) => http.Response('', 599));

      expect(rig.tokens.hasToken, isFalse, reason: 'the late refresh must not revive the session');
    });
  });

  group('proactive refresh', () {
    test('a token older than 13 minutes is refreshed before it is used', () async {
      var now = DateTime(2026, 10, 19, 9);
      final rig = _Rig(clock: () => now);
      addTearDown(rig.dispose);
      await rig.signIn();
      now = now.add(const Duration(minutes: 14));

      await rig.call('Wallet');

      expect(rig.backend.refreshCalls, 1);
      final wallet = rig.server.where('Wallet');
      expect(wallet, hasLength(1), reason: 'no failed attempt, no replay');
      expect(wallet.single.authorization, 'Bearer ${rig.backend.validToken}');
    });

    test('a fresh token is not refreshed', () async {
      var now = DateTime(2026, 10, 19, 9);
      final rig = _Rig(clock: () => now);
      addTearDown(rig.dispose);
      await rig.signIn();
      now = now.add(const Duration(minutes: 12));

      await rig.call('Wallet');

      expect(rig.backend.refreshCalls, 0);
    });
  });

  group('cookie rotation and persistence', () {
    test('consecutive refreshes each use the newest cookie', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();

      for (var i = 0; i < 3; i++) {
        rig.backend.expireAccessToken();
        await rig.call('Wallet');
      }

      expect(rig.backend.refreshCalls, 3);
      expect(rig.backend.sessionAlive, isTrue, reason: 'no rotated cookie was ever replayed');
    });

    test('the cookie survives a restart (a new jar over the same storage)', () async {
      final storage = MemoryCookieStorage();
      final first = _Rig(storage: storage);
      await first.signIn();
      first.backend.expireAccessToken();
      await first.call('Wallet'); // rotates once, new cookie persisted
      final backend = first.backend;
      await first.dispose();

      // "Restart": new objects, same storage, no access token in memory.
      final second = _Rig(storage: storage, backend: backend);
      addTearDown(second.dispose);
      final status = await second.api.coordinator.refresh();

      expect(status, RefreshStatus.refreshed);
      expect(second.tokens.token, backend.validToken);
      expect(backend.sessionAlive, isTrue);
    });

    test('the persisted entry holds the cookie, so it must live in encrypted storage', () async {
      final storage = MemoryCookieStorage();
      final rig = _Rig(storage: storage);
      addTearDown(rig.dispose);
      await rig.signIn();

      expect(storage.data.values.join(), contains('sb_refresh=${rig.backend.validRefresh}'));
    });

    test('the cookie is only sent to its own host', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();

      final other = await rig.jar.loadForRequest(Uri.parse('https://files.other.test/x'));
      final own = await rig.jar.loadForRequest(Uri.parse('https://api.seen.test/files/upload/'));

      expect(other, isEmpty);
      expect(own.map((c) => c.name), ['sb_refresh']);
    });

    test('a Secure cookie is not sent over plain http', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();

      expect(await rig.jar.loadForRequest(Uri.parse('http://api.seen.test/graphql/')), isEmpty);
    });

    test('an expired cookie is dropped even on https', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      // Age the stored cookie past its Max-Age (86400 s): creation time 2 days ago.
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch ~/ 1000;
      final aged = rig.storage.data.map((k, v) => MapEntry(k, v.replaceAll(RegExp(r';_crt=\d+'), ';_crt=$twoDaysAgo')));
      final restarted = StrictPersistCookieJar(storage: MemoryCookieStorage(aged));

      expect(await restarted.loadForRequest(_uri), isEmpty);
    });

    test('unreadable stored cookies mean "no cookie" instead of an error', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.signIn();
      final corrupt = rig.storage.data.map((k, v) => MapEntry(k, k == '.index' ? v : 'not json'));
      final restarted = StrictPersistCookieJar(storage: MemoryCookieStorage(corrupt));

      expect(await restarted.loadForRequest(_uri), isEmpty);
    });
  });

  group('transport behaviour', () {
    test('Set-Cookie never reaches the layers above', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);

      final response = await rig.client
          .post(_uri, headers: {'content-type': 'application/json'}, body: '{"query":"mutation Login { login }"}');

      expect(response.headers.keys.map((k) => k.toLowerCase()), isNot(contains('set-cookie')));
    });

    test('a timeout surfaces as TimeoutException and a lost connection as SocketException', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      rig.server.responder =
          (r) => throw DioException.receiveTimeout(timeout: const Duration(seconds: 1), requestOptions: r.options);
      await expectLater(rig.call('Wallet'), throwsA(isA<TimeoutException>()));

      rig.server.responder = (r) => throw DioException.connectionError(
            requestOptions: r.options,
            reason: 'down',
            error: const SocketException('down'),
          );
      await expectLater(rig.call('Wallet'), throwsA(isA<SocketException>()));
    });

    test('a redirect is not followed and reaches the caller as a status', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      rig.server.responder = (r) => ResponseBody.fromString('', 301, headers: {
            'location': ['https://api.seen.test/graphql']
          });

      final response = await rig.call('Wallet');

      expect(response.statusCode, 301);
      expect(rig.server.requests, hasLength(1));
    });

    test('HTTP error statuses reach the caller as statuses, not exceptions', () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      rig.server.responder = (r) => ResponseBody.fromString('busy', 429);

      final response = await rig.call('Wallet');

      expect(response.statusCode, 429);
    });
  });
}
