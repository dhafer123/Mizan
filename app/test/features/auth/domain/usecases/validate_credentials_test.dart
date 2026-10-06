import 'package:glados/glados.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/auth/domain/usecases/validate_credentials.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_error.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_failure.dart';
import 'package:mizan/features/auth/domain/value_objects/credentials.dart';

const _validate = ValidateCredentials();

Result<Credentials, AuthFailure> _signUp({
  String email = 'ali@example.com',
  String password = 'correct-horse',
  String? displayName,
}) => _validate(
  email: email,
  password: password,
  displayName: displayName,
  newAccount: true,
);

Result<Credentials, AuthFailure> _logIn({
  String email = 'ali@example.com',
  String password = 'x',
}) => _validate(email: email, password: password, newAccount: false);

AuthError? _error(Result<Credentials, AuthFailure> r) => r.failureOrNull?.error;

void main() {
  group('email', () {
    test('trimmed and lowercased', () {
      expect(
        _signUp(email: '  Ali@Example.COM ').valueOrNull?.email,
        'ali@example.com',
      );
    });

    for (final email in [
      '',
      '   ',
      'ali',
      'ali@',
      '@example.com',
      'ali@example',
      'ali @example.com',
      'ali@@example.com',
      '${'a' * 250}@x.tn',
    ]) {
      test('"$email" is invalid', () {
        expect(_error(_signUp(email: email)), AuthError.invalidEmail);
        expect(_error(_logIn(email: email)), AuthError.invalidEmail);
      });
    }

    test('254 characters is the limit', () {
      final email = '${'a' * 245}@mail.com';
      expect(email.length, 254);
      expect(_signUp(email: email).isOk, isTrue);
    });
  });

  group('password', () {
    test('required', () {
      expect(_error(_signUp(password: '')), AuthError.passwordRequired);
      expect(_error(_logIn(password: '')), AuthError.passwordRequired);
    });

    test('kept exactly as typed, spaces included', () {
      expect(
        _signUp(password: ' my secret ').valueOrNull?.password,
        ' my secret ',
      );
    });

    test('sign-up needs 8 to 128 characters', () {
      expect(_error(_signUp(password: '1234567')), AuthError.passwordLength);
      expect(_signUp(password: '12345678').isOk, isTrue);
      expect(_signUp(password: 'a' * 128).isOk, isTrue);
      expect(_error(_signUp(password: 'a' * 129)), AuthError.passwordLength);
    });

    test('sign-in takes any password; the server decides', () {
      expect(_logIn(password: '1').isOk, isTrue);
    });
  });

  group('display name', () {
    test('trimmed; blank is none', () {
      expect(_signUp(displayName: '  Ali ').valueOrNull?.displayName, 'Ali');
      expect(_signUp(displayName: '   ').valueOrNull?.displayName, isNull);
      expect(_signUp().valueOrNull?.displayName, isNull);
    });

    test('at most 50 characters', () {
      expect(_signUp(displayName: 'a' * 50).isOk, isTrue);
      expect(
        _error(_signUp(displayName: 'a' * 51)),
        AuthError.displayNameTooLong,
      );
    });

    test('ignored for sign-in', () {
      expect(
        _validate(
          email: 'ali@example.com',
          password: 'x',
          displayName: 'a' * 99,
          newAccount: false,
        ).valueOrNull,
        const Credentials(email: 'ali@example.com', password: 'x'),
      );
    });
  });

  test('toString never shows the password', () {
    final credentials = _signUp(password: 'hunter2-secret').valueOrNull!;
    expect(credentials.toString(), isNot(contains('hunter2')));
  });

  group('properties', () {
    final emails = any.choose([
      'ali@example.com',
      ' SAMI@Mail.TN ',
      'x@y.z',
      'Bad Email',
      '',
      'a@b',
    ]);

    Glados3(emails, any.letterOrDigits, any.letterOrDigits).test(
      'validating the cleaned result again changes nothing',
      (email, password, name) {
        final first = _signUp(
          email: email,
          password: password,
          displayName: name,
        );
        if (first case Ok(value: final c)) {
          expect(
            _signUp(
              email: c.email,
              password: c.password,
              displayName: c.displayName,
            ),
            first,
          );
          expect(c.email, c.email.trim().toLowerCase());
        }
      },
    );
  });
}
