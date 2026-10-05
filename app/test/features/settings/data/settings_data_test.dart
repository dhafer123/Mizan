import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/settings/data/export/platform_file_exporter.dart';
import 'package:mizan/features/settings/data/lock/secure_lock_settings_repository.dart';
import 'package:mizan/features/settings/domain/entities/lock_settings.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_error.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_failure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureLockSettingsRepository', () {
    const repository = SecureLockSettingsRepository(FlutterSecureStorage());

    test('no PIN stored: the lock is off', () async {
      FlutterSecureStorage.setMockInitialValues({});

      expect(
        await repository.load(),
        const Ok<LockSettings?, SettingsFailure>(null),
      );
    });

    test('saves, loads, and forgets', () async {
      FlutterSecureStorage.setMockInitialValues({});

      await repository.save(const LockSettings(pin: '2468', biometrics: true));
      expect(
        (await repository.load()).valueOrNull,
        const LockSettings(pin: '2468', biometrics: true),
      );

      await repository.save(null);
      expect((await repository.load()).valueOrNull, isNull);
      expect(
        await const FlutterSecureStorage().readAll(),
        isEmpty,
        reason: 'nothing left behind',
      );
    });
  });

  group('PlatformFileExporter', () {
    const channel = PlatformFileExporter.channel;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    Future<Result<bool, SettingsFailure>> save() => const PlatformFileExporter()
        .save(fileName: 'x.csv', mimeType: 'text/csv', bytes: [1, 2, 3]);

    test('passes the file to the platform; true when saved', () async {
      MethodCall? call;
      messenger.setMockMethodCallHandler(channel, (c) async {
        call = c;
        return true;
      });

      expect(await save(), const Ok<bool, SettingsFailure>(true));
      expect(call?.method, 'save');
      final args = call?.arguments as Map<Object?, Object?>;
      expect(args['fileName'], 'x.csv');
      expect(args['mimeType'], 'text/csv');
      expect(args['bytes'], Uint8List.fromList([1, 2, 3]));
    });

    test('false when the user cancelled', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => false);

      expect(await save(), const Ok<bool, SettingsFailure>(false));
    });

    test('a platform error, or no platform side, is a failure', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'write_failed'),
      );
      expect(
        await save(),
        const Err<bool, SettingsFailure>(
          SettingsFailure(SettingsError.exportFailed),
        ),
      );

      messenger.setMockMethodCallHandler(channel, null);
      expect(await save(), isA<Err<bool, SettingsFailure>>());
    });
  });
}
