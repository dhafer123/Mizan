import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/auth/data/remote/auth_api.dart';
import 'package:mizan/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mizan/features/auth/data/session/stored_session.dart';
import 'package:mizan/features/auth/data/session/token_pair.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_error.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_failure.dart';
import 'package:mizan/features/auth/domain/value_objects/credentials.dart';

import '../../../../support/fake_http_adapter.dart';
import '../../../../support/fake_session_store.dart';

const _ali = Account(id: '12', email: 'ali@example.com', displayName: 'Ali');
const _session = StoredSession(
  account: _ali,
  tokens: TokenPair(access: 'a', refresh: 'r'),
);
const _credentials = Credentials(email: 'ali@example.com', password: 'pw');
const _storage = AuthFailure(AuthError.storage);

final _sessionJson = {
  'user': {'id': '12', 'email': 'ali@example.com', 'displayName': 'Ali'},
  'access': 'a',
  'refresh': 'r',
};

void main() {
  late FakeHttpAdapter adapter;
  late FakeSessionStore store;
  late AuthRepositoryImpl repository;

  setUp(() {
    adapter = FakeHttpAdapter((_) => FakeHttpAdapter.json(200, _sessionJson));
    store = FakeSessionStore();
    repository = AuthRepositoryImpl(
      AuthApi(fakeDio(adapter)),
      store,
      platform: 'android',
    );
  });
  tearDown(() => repository.dispose());

  group('watchAccount', () {
    test('starts with the stored account, then follows changes', () async {
      store.session = _session;
      final seen = <Account?>[];
      final sub = repository.watchAccount().listen(seen.add);
      await pumpEventQueue();

      await repository.logOut();
      await repository.logIn(_credentials);
      await pumpEventQueue();

      expect(seen, [_ali, null, _ali]);
      await sub.cancel();
    });

    test('signed out: null', () async {
      expect(await repository.watchAccount().first, isNull);
    });

    test('storage error: a storage failure event', () async {
      store.error = Exception('keystore');

      await expectLater(repository.watchAccount(), emitsError(_storage));
    });

    test('a change while reading wins over the stale read', () async {
      final gated = _GatedReadStore()..session = _session;
      final repo = AuthRepositoryImpl(
        AuthApi(fakeDio(adapter)),
        gated,
        platform: 'android',
      );
      addTearDown(repo.dispose);
      final seen = <Account?>[];
      final sub = repo.watchAccount().listen(seen.add);
      await pumpEventQueue();

      // The session ends while the initial read is still waiting.
      await repo.endExpiredSession();
      gated.release.complete();
      await pumpEventQueue();

      expect(seen, [null]);
      await sub.cancel();
    });
  });

  group('logIn / signUp', () {
    test('stores the session and reports the account', () async {
      final changes = <Account?>[];
      final sub = repository.watchAccount().skip(1).listen(changes.add);
      await pumpEventQueue();

      final result = await repository.logIn(_credentials);
      await pumpEventQueue();

      expect(result, const Ok<Account, AuthFailure>(_ali));
      expect(store.session, _session);
      expect(changes, [_ali]);
      expect(
        adapter.requests.single.data,
        containsPair('device', {'id': 'device-1', 'platform': 'android'}),
      );
      await sub.cancel();
    });

    test('sign-up goes to /auth/signup', () async {
      adapter.handler = (_) => FakeHttpAdapter.json(201, _sessionJson);

      expect((await repository.signUp(_credentials)).valueOrNull, _ali);
      expect(adapter.requests.single.path, '/auth/signup');
    });

    test('a server failure stores nothing', () async {
      adapter.handler = (_) =>
          FakeHttpAdapter.json(401, {'code': 'invalid_credentials'});

      expect(
        (await repository.logIn(_credentials)).failureOrNull,
        const AuthFailure(AuthError.invalidCredentials),
      );
      expect(store.session, isNull);
    });

    test(
      'no device id (storage error): fails before calling the server',
      () async {
        store.error = Exception('keystore');

        expect((await repository.logIn(_credentials)).failureOrNull, _storage);
        expect(adapter.requests, isEmpty);
      },
    );

    test('signed in on the server but the session cannot be saved', () async {
      final failing = _WriteFailingStore();
      final repo = AuthRepositoryImpl(
        AuthApi(fakeDio(adapter)),
        failing,
        platform: 'android',
      );
      addTearDown(repo.dispose);

      expect((await repo.logIn(_credentials)).failureOrNull, _storage);
    });
  });

  group('logOut', () {
    test('revokes on the server, clears the session, reports null', () async {
      store.session = _session;
      adapter.handler = (_) => FakeHttpAdapter.json(204);
      final changes = <Account?>[];
      final sub = repository.watchAccount().skip(1).listen(changes.add);
      await pumpEventQueue();

      expect(await repository.logOut(), const Ok<void, AuthFailure>(null));
      await pumpEventQueue();

      expect(store.session, isNull);
      expect(changes, [null]);
      expect(adapter.requests.single.path, '/auth/logout');
      expect(adapter.requests.single.data, {
        'refresh': 'r',
        'deviceId': 'device-1',
      });
      await sub.cancel();
    });

    test('offline: still signs out here', () async {
      store.session = _session;
      adapter.handler = FakeHttpAdapter.offline;

      expect((await repository.logOut()).isOk, isTrue);
      expect(store.session, isNull);
    });

    test('already signed out: nothing to do', () async {
      expect((await repository.logOut()).isOk, isTrue);
      expect(adapter.requests, isEmpty);
    });

    test('storage error: a storage failure', () async {
      store.error = Exception('keystore');

      expect((await repository.logOut()).failureOrNull, _storage);
    });
  });

  test('endExpiredSession clears the session and reports null', () async {
    store.session = _session;
    final next = repository.watchAccount().skip(1).first;
    await pumpEventQueue();

    await repository.endExpiredSession();

    expect(await next, isNull);
    expect(store.session, isNull);
  });

  test('endExpiredSession reports null even if clearing fails', () async {
    final next = repository.watchAccount().skip(1).first;
    await pumpEventQueue();
    store.error = Exception('keystore');

    await repository.endExpiredSession();

    expect(await next.timeout(const Duration(seconds: 1)), isNull);
  });
}

class _WriteFailingStore extends FakeSessionStore {
  @override
  Future<void> write(StoredSession session) async => throw Exception('full');
}

/// Holds the first [read] until [release] completes.
class _GatedReadStore extends FakeSessionStore {
  final release = Completer<void>();

  @override
  Future<StoredSession?> read({bool fresh = false}) async {
    final session = this.session;
    await release.future;
    return session;
  }

  @override
  Future<void> clear() async => session = null;
}
