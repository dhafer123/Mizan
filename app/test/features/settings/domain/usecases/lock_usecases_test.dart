import 'package:glados/glados.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/settings/domain/entities/lock_settings.dart';
import 'package:mizan/features/settings/domain/usecases/disable_lock.dart';
import 'package:mizan/features/settings/domain/usecases/get_lock_status.dart';
import 'package:mizan/features/settings/domain/usecases/set_biometric_unlock.dart';
import 'package:mizan/features/settings/domain/usecases/set_pin.dart';
import 'package:mizan/features/settings/domain/usecases/unlock_with_biometrics.dart';
import 'package:mizan/features/settings/domain/usecases/unlock_with_pin.dart';
import 'package:mizan/features/settings/domain/usecases/validate_pin.dart';
import 'package:mizan/features/settings/domain/value_objects/lock_status.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_error.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_failure.dart';

import '../../../../support/fake_biometric_authenticator.dart';
import '../../../../support/fake_lock_settings_repository.dart';

Err<T, SettingsFailure> _err<T>(SettingsError error) =>
    Err(SettingsFailure(error));

/// Strings of 0-12 characters, mostly digits.
extension _PinAnys on Any {
  Generator<String> get pinLike => any
      .listWithLengthInRange(
        0,
        12,
        any.choose(['0', '1', '5', '9', '3', '7', 'a', ' ', '-', '٣']),
      )
      .map((chars) => chars.join());
}

void main() {
  group('ValidatePin', () {
    const validate = ValidatePin();

    test('4 to 6 digits', () {
      expect(validate('1234'), const Ok<String, SettingsFailure>('1234'));
      expect(validate('000000'), isA<Ok<String, SettingsFailure>>());
    });

    test('too short, too long, or not digits', () {
      for (final pin in ['', '123', '1234567', '12a4', '12 34', '١٢٣٤']) {
        expect(
          validate(pin),
          _err<String>(SettingsError.pinFormat),
          reason: pin,
        );
      }
    });

    Glados(any.pinLike).test('valid exactly when 4-6 ASCII digits', (pin) {
      final valid = RegExp(r'^[0-9]{4,6}$').hasMatch(pin);
      expect(validate(pin) is Ok, valid);
    });
  });

  group('SetPin', () {
    test('turns the lock on', () async {
      final repository = FakeLockSettingsRepository();
      final result = await SetPin(repository, const ValidatePin())(
        pin: '2468',
        confirmation: '2468',
      );

      expect(result, isA<Ok<void, SettingsFailure>>());
      expect(repository.settings, const LockSettings(pin: '2468'));
    });

    test('a new PIN keeps the biometrics choice', () async {
      final repository = FakeLockSettingsRepository(
        const LockSettings(pin: '1111', biometrics: true),
      );
      await SetPin(repository, const ValidatePin())(
        pin: '2222',
        confirmation: '2222',
      );

      expect(
        repository.settings,
        const LockSettings(pin: '2222', biometrics: true),
      );
    });

    test('the confirmation must match; the format is checked first', () async {
      final repository = FakeLockSettingsRepository();
      final setPin = SetPin(repository, const ValidatePin());

      expect(
        await setPin(pin: '1234', confirmation: '1243'),
        _err<void>(SettingsError.pinMismatch),
      );
      expect(
        await setPin(pin: '12', confirmation: '12'),
        _err<void>(SettingsError.pinFormat),
      );
      expect(repository.settings, isNull);
    });

    test('a storage failure is returned', () async {
      final repository = FakeLockSettingsRepository()
        ..saveFailure = const SettingsFailure(SettingsError.storage);

      expect(
        await SetPin(repository, const ValidatePin())(
          pin: '1234',
          confirmation: '1234',
        ),
        _err<void>(SettingsError.storage),
      );
    });
  });

  test('DisableLock forgets the PIN', () async {
    final repository = FakeLockSettingsRepository(
      const LockSettings(pin: '1234', biometrics: true),
    );
    await DisableLock(repository)();

    expect(repository.settings, isNull);
  });

  group('GetLockStatus', () {
    test('never exposes the PIN; reports what can unlock', () async {
      final status = await GetLockStatus(
        FakeLockSettingsRepository(
          const LockSettings(pin: '1234', biometrics: true),
        ),
        FakeBiometricAuthenticator(),
      )();

      expect(
        status,
        const Ok<LockStatus, SettingsFailure>(
          LockStatus(
            enabled: true,
            biometrics: true,
            biometricsAvailable: true,
          ),
        ),
      );
    });

    test('lock off', () async {
      final status = await GetLockStatus(
        FakeLockSettingsRepository(),
        FakeBiometricAuthenticator(available: false),
      )();

      expect(
        status.valueOrNull,
        const LockStatus(
          enabled: false,
          biometrics: false,
          biometricsAvailable: false,
        ),
      );
    });
  });

  group('SetBiometricUnlock', () {
    test('turning it on needs one successful check', () async {
      final repository = FakeLockSettingsRepository(
        const LockSettings(pin: '1234'),
      );
      final biometrics = FakeBiometricAuthenticator();

      final result = await SetBiometricUnlock(repository, biometrics)(
        enabled: true,
      );

      expect(result, isA<Ok<void, SettingsFailure>>());
      expect(repository.settings?.biometrics, isTrue);
      expect(biometrics.reasons, [SetBiometricUnlock.reason]);
    });

    test('a failed check leaves it off', () async {
      final repository = FakeLockSettingsRepository(
        const LockSettings(pin: '1234'),
      );

      expect(
        await SetBiometricUnlock(
          repository,
          FakeBiometricAuthenticator(passes: false),
        )(enabled: true),
        _err<void>(SettingsError.biometricsFailed),
      );
      expect(repository.settings?.biometrics, isFalse);
    });

    test('not without biometrics on the phone, or without the lock', () async {
      expect(
        await SetBiometricUnlock(
          FakeLockSettingsRepository(const LockSettings(pin: '1234')),
          FakeBiometricAuthenticator(available: false),
        )(enabled: true),
        _err<void>(SettingsError.biometricsUnavailable),
      );
      expect(
        await SetBiometricUnlock(
          FakeLockSettingsRepository(),
          FakeBiometricAuthenticator(),
        )(enabled: true),
        _err<void>(SettingsError.biometricsUnavailable),
      );
    });

    test('turning it off needs no check', () async {
      final repository = FakeLockSettingsRepository(
        const LockSettings(pin: '1234', biometrics: true),
      );
      final biometrics = FakeBiometricAuthenticator(passes: false);

      await SetBiometricUnlock(repository, biometrics)(enabled: false);

      expect(repository.settings, const LockSettings(pin: '1234'));
      expect(biometrics.reasons, isEmpty);
    });
  });

  group('UnlockWithPin', () {
    late FakeClock clock;
    late UnlockWithPin unlock;

    setUp(() {
      clock = FakeClock(DateTime.utc(2026, 10, 6, 9));
      unlock = UnlockWithPin(
        FakeLockSettingsRepository(const LockSettings(pin: '2468')),
        clock,
      );
    });

    test('the right PIN unlocks; a wrong one does not', () async {
      expect(await unlock('2468'), isA<Ok<void, SettingsFailure>>());
      expect(await unlock('2469'), _err<void>(SettingsError.wrongPin));
      expect(await unlock('24680'), _err<void>(SettingsError.wrongPin));
      expect(await unlock('246'), _err<void>(SettingsError.wrongPin));
    });

    test('five wrong in a row block every try for 30 seconds', () async {
      for (var i = 1; i < UnlockWithPin.maxAttempts; i++) {
        expect(await unlock('0000'), _err<void>(SettingsError.wrongPin));
      }
      expect(await unlock('0000'), _err<void>(SettingsError.tooManyAttempts));
      // Even the right PIN, until the cooldown ends.
      expect(await unlock('2468'), _err<void>(SettingsError.tooManyAttempts));

      clock.advance(const Duration(seconds: 29));
      expect(await unlock('2468'), _err<void>(SettingsError.tooManyAttempts));
      clock.advance(const Duration(seconds: 1));
      expect(await unlock('2468'), isA<Ok<void, SettingsFailure>>());
    });

    test('a right PIN resets the count', () async {
      for (var i = 1; i < UnlockWithPin.maxAttempts; i++) {
        await unlock('0000');
      }
      await unlock('2468');
      expect(await unlock('0000'), _err<void>(SettingsError.wrongPin));
    });
  });

  group('UnlockWithBiometrics', () {
    test('unlocks when turned on and the check passes', () async {
      final biometrics = FakeBiometricAuthenticator();
      final result = await UnlockWithBiometrics(
        FakeLockSettingsRepository(
          const LockSettings(pin: '1234', biometrics: true),
        ),
        biometrics,
      )();

      expect(result, isA<Ok<void, SettingsFailure>>());
      expect(biometrics.reasons, [UnlockWithBiometrics.reason]);
    });

    test('fails when the check fails', () async {
      expect(
        await UnlockWithBiometrics(
          FakeLockSettingsRepository(
            const LockSettings(pin: '1234', biometrics: true),
          ),
          FakeBiometricAuthenticator(passes: false),
        )(),
        _err<void>(SettingsError.biometricsFailed),
      );
    });

    test('never asks when the user did not turn it on', () async {
      final biometrics = FakeBiometricAuthenticator();

      expect(
        await UnlockWithBiometrics(
          FakeLockSettingsRepository(const LockSettings(pin: '1234')),
          biometrics,
        )(),
        _err<void>(SettingsError.biometricsUnavailable),
      );
      expect(biometrics.reasons, isEmpty);
    });
  });
}
