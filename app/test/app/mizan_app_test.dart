import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/database_providers.dart';
import 'package:mizan/app/di/settings_providers.dart';
import 'package:mizan/app/mizan_app.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/features/budget/presentation/home/home_screen.dart';

import '../support/fake_biometric_authenticator.dart';
import '../support/fake_lock_settings_repository.dart';
import '../support/test_database.dart';

void main() {
  testWidgets('boots into the home screen through the router', (tester) async {
    final db = openTestDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(FakeClock(testNow)),
          appDatabaseProvider.overrideWithValue(db),
          lockSettingsRepositoryProvider.overrideWithValue(
            FakeLockSettingsRepository(),
          ),
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(available: false),
          ),
        ],
        child: const MizanApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);

    // Unmount so drift's query streams close, then close the database.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    final closing = db.close();
    await tester.pump(const Duration(seconds: 1));
    await closing;
  });
}
