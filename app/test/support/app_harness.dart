import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/app/di/auth_providers.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/database_providers.dart';
import 'package:mizan/app/di/quick_input_providers.dart';
import 'package:mizan/app/di/settings_providers.dart';
import 'package:mizan/app/di/sync_providers.dart';
import 'package:mizan/app/mizan_app.dart';
import 'package:mizan/core/clock/fake_clock.dart';

import 'fake_auth_repository.dart';
import 'fake_biometric_authenticator.dart';
import 'fake_device_preferences_repository.dart';
import 'fake_expense_llm.dart';
import 'fake_lock_settings_repository.dart';
import 'fake_push_messaging.dart';
import 'fake_sync_repository.dart';
import 'test_database.dart';

/// The whole app on an in-memory database, signed out, with no network,
/// push, lock or assistant. Call [shutDown] at the end of the test.
class AppHarness {
  AppHarness({FakeDevicePreferencesRepository? preferences})
    : preferences =
          preferences ?? FakeDevicePreferencesRepository(onboarded: true);

  final FakeDevicePreferencesRepository preferences;
  late final AppDatabase db;
  late final ProviderContainer container;

  Future<void> boot(WidgetTester tester) async {
    db = openTestDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(FakeClock(testNow)),
          appDatabaseProvider.overrideWithValue(db),
          devicePreferencesRepositoryProvider.overrideWithValue(preferences),
          lockSettingsRepositoryProvider.overrideWithValue(
            FakeLockSettingsRepository(),
          ),
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(available: false),
          ),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          connectivityMonitorProvider.overrideWithValue(FakeConnectivity()),
          backgroundSyncProvider.overrideWithValue(FakeBackgroundSync()),
          pushMessagingProvider.overrideWithValue(FakePushMessaging()),
          expenseLlmProvider.overrideWithValue(FakeExpenseLlm()),
        ],
        child: const MizanApp(),
      ),
    );
    // The first route waits on an async redirect (the onboarding check reads
    // the database), and with no frame scheduled pumpAndSettle alone would
    // stop before drift's timers run.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(MizanApp)),
    );
  }

  Future<void> shutDown(WidgetTester tester) async {
    // Unmount so drift's query streams close, then close the database.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    final closing = db.close();
    await tester.pump(const Duration(seconds: 1));
    await closing;
  }
}
