import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/auth/data/remote/auth_api.dart';
import 'package:mizan/features/auth/data/remote/auth_interceptor.dart';
import 'package:mizan/features/auth/data/session/stored_session.dart';
import 'package:mizan/features/auth/data/session/token_pair.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';

import '../../../../support/fake_http_adapter.dart';
import '../../../../support/fake_session_store.dart';

const _account = Account(id: '7', email: 'sami@example.com');
const _old = TokenPair(access: 'access-1', refresh: 'refresh-1');
const _new = TokenPair(access: 'access-2', refresh: 'refresh-2');
const _session = StoredSession(account: _account, tokens: _old);

/// A pretend server: `/data` wants `Bearer <validAccess>`, `/auth/refresh`
/// answers with [refresh].
class _Server {
  var validAccess = _old.access;
  FutureOr<ResponseBody> Function(RequestOptions) refresh = (_) =>
      FakeHttpAdapter.json(200, {
        'access': _new.access,
        'refresh': _new.refresh,
      });

  /// Runs before `/data` answers (e.g. to sign out mid-request).
  void Function()? beforeData;

  late final adapter = FakeHttpAdapter((r) {
    if (r.path == AuthApi.refreshPath) return refresh(r);
    beforeData?.call();
    return r.headers['Authorization'] == 'Bearer $validAccess'
        ? FakeHttpAdapter.json(200, {'ok': true})
        : FakeHttpAdapter.json(401, {'code': 'token_not_valid'});
  });

  List<RequestOptions> get refreshes => adapter.to(AuthApi.refreshPath);
  List<RequestOptions> get data => adapter.to('/data');
}

void main() {
  late _Server server;
  late FakeSessionStore store;
  late Dio dio;
  late int expired;

  setUp(() {
    server = _Server();
    store = FakeSessionStore(_session);
    expired = 0;
    final plain = fakeDio(server.adapter);
    dio = fakeDio(server.adapter)
      ..interceptors.add(
        AuthInterceptor(
          store: store,
          api: AuthApi(plain),
          retryDio: plain,
          onSessionExpired: () async {
            expired++;
            await store.clear();
          },
        ),
      );
  });

  Matcher failsWith(int status) => throwsA(
    isA<DioException>().having((e) => e.response?.statusCode, 'status', status),
  );

  test('sends the access token', () async {
    final response = await dio.get<Object?>('/data');

    expect(response.statusCode, 200);
    expect(server.data.single.headers['Authorization'], 'Bearer access-1');
    expect(server.refreshes, isEmpty);
  });

  test(
    'signed out: no token, and a 401 is passed on without a refresh',
    () async {
      store.session = null;

      await expectLater(dio.get<Object?>('/data'), failsWith(401));
      expect(server.data.single.headers.containsKey('Authorization'), isFalse);
      expect(server.refreshes, isEmpty);
    },
  );

  test('expired access token: refreshes once, stores the new pair and '
      'retries the request as it was', () async {
    server.validAccess = _new.access;

    final response = await dio.post<Object?>('/data', data: {'amount': 4500});

    expect(response.statusCode, 200);
    expect(server.refreshes.single.data, {'refresh': 'refresh-1'});
    expect(
      server.refreshes.single.headers.containsKey('Authorization'),
      isFalse,
    );
    expect(store.session, _session.copyWith(tokens: _new));
    expect(server.data, hasLength(2));
    final retry = server.data.last;
    expect(retry.method, 'POST');
    expect(retry.data, {'amount': 4500});
    expect(retry.headers['Authorization'], 'Bearer access-2');
  });

  test('later requests use the new token straight away', () async {
    server.validAccess = _new.access;
    await dio.get<Object?>('/data');
    server.adapter.requests.clear();

    await dio.get<Object?>('/data');

    expect(server.data.single.headers['Authorization'], 'Bearer access-2');
    expect(server.refreshes, isEmpty);
  });

  test('requests that fail together share one refresh '
      '(a refresh token works only once)', () async {
    server.validAccess = _new.access;
    final refreshing = Completer<void>();
    server.refresh = (_) async {
      await refreshing.future;
      return FakeHttpAdapter.json(200, {
        'access': _new.access,
        'refresh': _new.refresh,
      });
    };

    final requests = [for (var i = 0; i < 3; i++) dio.get<Object?>('/data')];
    await pumpEventQueue();
    refreshing.complete();
    final responses = await Future.wait(requests);

    expect(responses.map((r) => r.statusCode), [200, 200, 200]);
    expect(server.refreshes, hasLength(1));
    expect(store.writes, 1);
  });

  test(
    'refresh token rejected: signs out here and passes the 401 on',
    () async {
      server.validAccess = _new.access;
      server.refresh = (_) =>
          FakeHttpAdapter.json(401, {'code': 'token_not_valid'});

      await expectLater(dio.get<Object?>('/data'), failsWith(401));
      expect(expired, 1);
      expect(store.session, isNull);
      expect(server.data, hasLength(1), reason: 'not retried');
    },
  );

  test('refresh offline: keeps the session and passes the 401 on', () async {
    server.validAccess = _new.access;
    server.refresh = FakeHttpAdapter.offline;

    await expectLater(dio.get<Object?>('/data'), failsWith(401));
    expect(expired, 0);
    expect(store.session, _session);
  });

  test('refresh server error: keeps the session', () async {
    server.validAccess = _new.access;
    server.refresh = (_) => FakeHttpAdapter.json(500, {'code': 'error'});

    await expectLater(dio.get<Object?>('/data'), failsWith(401));
    expect(expired, 0);
    expect(store.session, _session);
  });

  test('refresh answers with a bad body: keeps the session', () async {
    server.validAccess = _new.access;
    server.refresh = (_) => FakeHttpAdapter.json(200, {'access': 'only'});

    await expectLater(dio.get<Object?>('/data'), failsWith(401));
    expect(expired, 0);
    expect(store.session, _session);
  });

  test('a retried request that fails again is passed on: no loop', () async {
    server.validAccess = 'never';

    await expectLater(dio.get<Object?>('/data'), failsWith(401));
    expect(server.refreshes, hasLength(1));
    expect(server.data, hasLength(2));
  });

  test('other errors are passed on untouched', () async {
    server.adapter.handler = (_) => FakeHttpAdapter.json(500, {'code': 'x'});

    await expectLater(dio.get<Object?>('/data'), failsWith(500));
    expect(server.refreshes, isEmpty);
  });

  test('signed out while the request was in flight: no refresh', () async {
    server.validAccess = _new.access;
    server.beforeData = () => store.session = null;

    await expectLater(dio.get<Object?>('/data'), failsWith(401));
    expect(server.refreshes, isEmpty);
    expect(expired, 0);
  });

  test('unreadable session storage: sends without a token', () async {
    store.error = Exception('keystore');

    await expectLater(dio.get<Object?>('/data'), failsWith(401));
    expect(server.data.single.headers.containsKey('Authorization'), isFalse);
    expect(server.refreshes, isEmpty);
  });
}
