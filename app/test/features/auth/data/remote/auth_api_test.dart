import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/auth/data/remote/auth_api.dart';
import 'package:mizan/features/auth/data/remote/device_info.dart';
import 'package:mizan/features/auth/data/session/stored_session.dart';
import 'package:mizan/features/auth/data/session/token_pair.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_error.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_failure.dart';
import 'package:mizan/features/auth/domain/value_objects/credentials.dart';

import '../../../../support/fake_http_adapter.dart';

const _device = DeviceInfo(id: 'device-1', platform: 'android');
const _credentials = Credentials(
  email: 'ali@example.com',
  password: 'correct-horse',
  displayName: 'Ali',
);

Map<String, Object?> _sessionJson({String displayName = 'Ali'}) => {
  'user': {'id': '12', 'email': 'ali@example.com', 'displayName': displayName},
  'access': 'a',
  'refresh': 'r',
};

Map<String, Object?> _invalid(String field, List<String> codes) => {
  'code': 'invalid',
  'detail': 'Some fields are invalid.',
  'fields': {
    field: [
      for (final code in codes) {'code': code, 'message': '...'},
    ],
  },
};

void main() {
  late FakeHttpAdapter adapter;
  late AuthApi api;

  setUp(() {
    adapter = FakeHttpAdapter((_) => FakeHttpAdapter.json(200));
    api = AuthApi(fakeDio(adapter));
  });

  void answer(int status, [Object? body]) =>
      adapter.handler = (_) => FakeHttpAdapter.json(status, body);

  group('sign-up', () {
    test('sends the form and the device; returns the session', () async {
      answer(201, _sessionJson());

      final result = await api.signUp(_credentials, _device);

      expect(
        result.valueOrNull,
        const StoredSession(
          account: Account(
            id: '12',
            email: 'ali@example.com',
            displayName: 'Ali',
          ),
          tokens: TokenPair(access: 'a', refresh: 'r'),
        ),
      );
      final request = adapter.requests.single;
      expect(request.path, '/auth/signup');
      expect(request.method, 'POST');
      expect(request.data, {
        'email': 'ali@example.com',
        'password': 'correct-horse',
        'displayName': 'Ali',
        'device': {'id': 'device-1', 'platform': 'android'},
      });
    });

    test('a blank display name from the server is none', () async {
      answer(201, _sessionJson(displayName: ''));

      final result = await api.signUp(_credentials, _device);

      expect(result.valueOrNull?.account.displayName, isNull);
    });

    final cases = <(String, int, Object?, AuthError)>[
      (
        'email taken',
        400,
        _invalid('email', ['email_taken']),
        AuthError.emailTaken,
      ),
      (
        'bad email',
        400,
        _invalid('email', ['invalid']),
        AuthError.invalidEmail,
      ),
      (
        'weak password',
        400,
        _invalid('password', ['password_too_common', 'password_too_short']),
        AuthError.weakPassword,
      ),
      (
        'blank password',
        400,
        _invalid('password', ['blank']),
        AuthError.passwordRequired,
      ),
      (
        'long name',
        400,
        _invalid('displayName', ['max_length']),
        AuthError.displayNameTooLong,
      ),
      (
        'unknown field',
        400,
        _invalid('device.id', ['invalid']),
        AuthError.server,
      ),
      ('fields missing', 400, {'code': 'invalid'}, AuthError.server),
      ('throttled', 429, {'code': 'throttled'}, AuthError.tooManyAttempts),
      ('server error', 500, null, AuthError.server),
      ('not JSON', 502, 'Bad gateway', AuthError.server),
      (
        'bad success body',
        201,
        {'user': <String, Object?>{}},
        AuthError.server,
      ),
    ];
    for (final (name, status, body, error) in cases) {
      test('$name → $error', () async {
        answer(status, body);

        expect(
          await api.signUp(_credentials, _device),
          Err<StoredSession, AuthFailure>(AuthFailure(error)),
        );
      });
    }
  });

  group('sign-in', () {
    test('sends email, password and device', () async {
      answer(200, _sessionJson());

      final result = await api.logIn(_credentials, _device);

      expect(result.isOk, isTrue);
      expect(adapter.requests.single.path, '/auth/login');
      expect(adapter.requests.single.data, {
        'email': 'ali@example.com',
        'password': 'correct-horse',
        'device': {'id': 'device-1', 'platform': 'android'},
      });
    });

    final cases = <(String, int, Object?, AuthError)>[
      (
        'wrong password',
        401,
        {'code': 'invalid_credentials'},
        AuthError.invalidCredentials,
      ),
      (
        'password too long for the server',
        400,
        _invalid('password', ['max_length']),
        AuthError.invalidCredentials,
      ),
      ('other 401', 401, {'code': 'something_else'}, AuthError.server),
    ];
    for (final (name, status, body, error) in cases) {
      test('$name → $error', () async {
        answer(status, body);

        expect(
          (await api.logIn(_credentials, _device)).failureOrNull,
          AuthFailure(error),
        );
      });
    }
  });

  group('network failures are "offline"', () {
    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      test('$type', () async {
        adapter.handler = (r) =>
            throw DioException(requestOptions: r, type: type);

        expect(
          (await api.logIn(_credentials, _device)).failureOrNull,
          const AuthFailure(AuthError.offline),
        );
      });
    }

    test('anything else is a server failure', () async {
      adapter.handler = (r) =>
          throw DioException(requestOptions: r, type: DioExceptionType.cancel);

      expect(
        (await api.logIn(_credentials, _device)).failureOrNull,
        const AuthFailure(AuthError.server),
      );
    });
  });

  group('refresh and log-out', () {
    test('refresh returns the new pair', () async {
      answer(200, {'access': 'a2', 'refresh': 'r2'});

      expect(
        await api.refresh('r1'),
        const TokenPair(access: 'a2', refresh: 'r2'),
      );
      expect(adapter.requests.single.path, '/auth/refresh');
      expect(adapter.requests.single.data, {'refresh': 'r1'});
    });

    test('refresh throws when rejected', () async {
      answer(401, {'code': 'token_not_valid'});

      await expectLater(api.refresh('r1'), throwsA(isA<DioException>()));
    });

    test('log-out sends the refresh token and the device id', () async {
      answer(204);

      await api.logOut(refreshToken: 'r1', deviceId: 'device-1');

      expect(adapter.requests.single.path, '/auth/logout');
      expect(adapter.requests.single.data, {
        'refresh': 'r1',
        'deviceId': 'device-1',
      });
    });
  });
}
