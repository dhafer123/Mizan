import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';
import 'package:mizan/features/auth/domain/usecases/log_in.dart';
import 'package:mizan/features/auth/domain/usecases/log_out.dart';
import 'package:mizan/features/auth/domain/usecases/sign_up.dart';
import 'package:mizan/features/auth/domain/usecases/validate_credentials.dart';
import 'package:mizan/features/auth/domain/usecases/watch_account.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_error.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_failure.dart';
import 'package:mizan/features/auth/domain/value_objects/credentials.dart';

import '../../../../support/fake_auth_repository.dart';

const _validate = ValidateCredentials();

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

  group('SignUp', () {
    test('sends cleaned-up credentials and returns the account', () async {
      final result = await SignUp(repository, _validate)(
        email: ' Ali@Example.com',
        password: 'correct-horse',
        displayName: ' Ali ',
      );

      expect(
        result,
        const Ok<Account, AuthFailure>(
          Account(id: 'user-1', email: 'ali@example.com', displayName: 'Ali'),
        ),
      );
      expect(
        repository.credentials.single,
        const Credentials(
          email: 'ali@example.com',
          password: 'correct-horse',
          displayName: 'Ali',
        ),
      );
    });

    test('invalid input never reaches the server', () async {
      final result = await SignUp(repository, _validate)(
        email: 'ali@example.com',
        password: 'short',
      );

      expect(result.failureOrNull, const AuthFailure(AuthError.passwordLength));
      expect(repository.calls, isEmpty);
    });

    test('passes server failures on', () async {
      repository.failure = const AuthFailure(AuthError.emailTaken);

      final result = await SignUp(repository, _validate)(
        email: 'ali@example.com',
        password: 'correct-horse',
      );

      expect(result.failureOrNull, const AuthFailure(AuthError.emailTaken));
    });
  });

  group('LogIn', () {
    test('sends cleaned-up credentials', () async {
      final result = await LogIn(repository, _validate)(
        email: 'SAMI@example.com ',
        password: 'pw',
      );

      expect(result.valueOrNull?.email, 'sami@example.com');
      expect(repository.calls, ['logIn']);
    });

    test('invalid input never reaches the server', () async {
      final result = await LogIn(repository, _validate)(
        email: 'nope',
        password: 'pw',
      );

      expect(result.failureOrNull, const AuthFailure(AuthError.invalidEmail));
      expect(repository.calls, isEmpty);
    });

    test('passes server failures on', () async {
      repository.failure = const AuthFailure(AuthError.invalidCredentials);

      final result = await LogIn(repository, _validate)(
        email: 'sami@example.com',
        password: 'wrong',
      );

      expect(
        result.failureOrNull,
        const AuthFailure(AuthError.invalidCredentials),
      );
    });
  });

  group('LogOut', () {
    test('signs out', () async {
      final repo = FakeAuthRepository(
        const Account(id: '1', email: 'sami@example.com'),
      );

      expect(await LogOut(repo)(), const Ok<void, AuthFailure>(null));
      expect(repo.account, isNull);
    });

    test('passes failures on', () async {
      repository.failure = const AuthFailure(AuthError.storage);

      expect(
        (await LogOut(repository)()).failureOrNull,
        const AuthFailure(AuthError.storage),
      );
    });
  });

  test('WatchAccount follows sign-in and sign-out', () async {
    final seen = <Account?>[];
    final sub = WatchAccount(repository)().listen(seen.add);
    await pumpEventQueue();

    await LogIn(repository, _validate)(email: 'a@b.tn', password: 'pw');
    await LogOut(repository)();
    await pumpEventQueue();

    expect(seen, [null, const Account(id: 'user-1', email: 'a@b.tn'), null]);
    await sub.cancel();
  });

  test('every failure has a message', () {
    for (final error in AuthError.values) {
      expect(AuthFailure(error).message, isNotEmpty, reason: '$error');
    }
  });
}
