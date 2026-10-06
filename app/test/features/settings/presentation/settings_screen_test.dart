import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mizan/app/di/auth_providers.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/expenses_providers.dart';
import 'package:mizan/app/di/settings_providers.dart';
import 'package:mizan/app/router/app_router.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/settings/domain/entities/lock_settings.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_error.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_failure.dart';
import 'package:mizan/features/settings/presentation/pin/pin_setup_screen.dart';
import 'package:mizan/features/settings/presentation/settings_screen.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_biometric_authenticator.dart';
import '../../../support/fake_category_repository.dart';
import '../../../support/fake_expense_repository.dart';
import '../../../support/fake_file_exporter.dart';
import '../../../support/fake_lock_settings_repository.dart';

Expense _expense(String id) => Expense(
  id: id,
  amount: const Money(3500, Currency.tnd),
  categoryId: 'food',
  date: DateTime.utc(2026, 10, 3),
);

class _Setup {
  _Setup({LockSettings? lock, bool biometricsAvailable = true})
    : lock = FakeLockSettingsRepository(lock),
      biometrics = FakeBiometricAuthenticator(available: biometricsAvailable);

  final FakeLockSettingsRepository lock;
  final FakeBiometricAuthenticator biometrics;
  final expenses = FakeExpenseRepository([_expense('a'), _expense('b')]);
  final exporter = FakeFileExporter();
}

Future<_Setup> _pump(WidgetTester tester, [_Setup? setup]) async {
  final s = setup ?? _Setup();
  final router = GoRouter(
    initialLocation: AppRoutes.settings,
    routes: [
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.pin,
        builder: (context, state) => const PinSetupScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(
          FakeClock(DateTime.utc(2026, 10, 6, 9)),
        ),
        lockSettingsRepositoryProvider.overrideWithValue(s.lock),
        biometricAuthenticatorProvider.overrideWithValue(s.biometrics),
        fileExporterProvider.overrideWithValue(s.exporter),
        expenseRepositoryProvider.overrideWithValue(s.expenses),
        categoryRepositoryProvider.overrideWithValue(
          FakeCategoryRepository(DefaultCategories.all),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  return s;
}

Future<void> _typePin(WidgetTester tester, String pin, String button) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.widgetWithText(TextButton, digit));
    await tester.pump();
  }
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
}

Finder _switch(String title) => find.widgetWithText(SwitchListTile, title);

bool _isOn(WidgetTester tester, String title) =>
    tester.widget<SwitchListTile>(_switch(title)).value;

void main() {
  testWidgets('loading, then the settings', (tester) async {
    await _pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Sign in to sync'), findsOneWidget);
    expect(_isOn(tester, 'App lock'), isFalse);
    expect(find.text('Change PIN'), findsNothing);
    expect(find.text('Export expenses'), findsOneWidget);
  });

  testWidgets('a storage failure shows, and can be retried', (tester) async {
    final setup = _Setup()
      ..lock.loadFailure = const SettingsFailure(SettingsError.storage);
    await _pump(tester, setup);
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save on this device. Try again."),
      findsOneWidget,
    );

    setup.lock.loadFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('App lock'), findsOneWidget);
  });

  group('turning the lock on', () {
    testWidgets('choose a PIN, confirm it, and the lock is on', (tester) async {
      final setup = await _pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(_switch('App lock'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a 4 to 6 digit PIN'), findsOneWidget);
      await _typePin(tester, '1357', 'Next');
      expect(find.text('Enter it again'), findsOneWidget);
      await _typePin(tester, '1357', 'Save PIN');

      expect(setup.lock.settings, const LockSettings(pin: '1357'));
      expect(find.text('App lock is on.'), findsOneWidget);
      expect(_isOn(tester, 'App lock'), isTrue);
      expect(find.text('Change PIN'), findsOneWidget);
    });

    testWidgets('a mismatch starts over', (tester) async {
      final setup = await _pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(_switch('App lock'));
      await tester.pumpAndSettle();

      await _typePin(tester, '1357', 'Next');
      await _typePin(tester, '7531', 'Save PIN');

      expect(find.text("The PINs don't match. Try again."), findsOneWidget);
      expect(find.text('Choose a 4 to 6 digit PIN'), findsOneWidget);
      expect(setup.lock.settings, isNull);
    });

    testWidgets('fewer than 4 digits cannot go on', (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(_switch('App lock'));
      await tester.pumpAndSettle();

      for (final digit in ['1', '2', '3']) {
        await tester.tap(find.widgetWithText(TextButton, digit));
      }
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('backing out leaves it off', (tester) async {
      final setup = await _pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(_switch('App lock'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(setup.lock.settings, isNull);
      expect(_isOn(tester, 'App lock'), isFalse);
    });
  });

  group('with the lock on', () {
    _Setup on({bool biometricsAvailable = true}) => _Setup(
      lock: const LockSettings(pin: '2468'),
      biometricsAvailable: biometricsAvailable,
    );

    testWidgets('turning it off asks first', (tester) async {
      final setup = await _pump(tester, on());
      await tester.pumpAndSettle();

      await tester.tap(_switch('App lock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(setup.lock.settings, isNotNull);

      await tester.tap(_switch('App lock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();

      expect(setup.lock.settings, isNull);
      expect(find.text('App lock is off.'), findsOneWidget);
      expect(_isOn(tester, 'App lock'), isFalse);
    });

    testWidgets('change the PIN', (tester) async {
      final setup = await _pump(tester, on());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change PIN'));
      await tester.pumpAndSettle();
      await _typePin(tester, '864200', 'Next');
      await _typePin(tester, '864200', 'Save PIN');

      expect(setup.lock.settings?.pin, '864200');
      expect(find.text('PIN changed.'), findsOneWidget);
    });

    testWidgets('biometrics: turned on after one check', (tester) async {
      final setup = await _pump(tester, on());
      await tester.pumpAndSettle();
      const title = 'Unlock with fingerprint or face';

      await tester.tap(_switch(title));
      await tester.pumpAndSettle();

      expect(setup.lock.settings?.biometrics, isTrue);
      expect(_isOn(tester, title), isTrue);
    });

    testWidgets('biometrics: a failed check says so', (tester) async {
      final setup = await _pump(tester, on());
      setup.biometrics.passes = false;
      await tester.pumpAndSettle();
      const title = 'Unlock with fingerprint or face';

      await tester.tap(_switch(title));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't confirm it's you."), findsOneWidget);
      expect(_isOn(tester, title), isFalse);
    });

    testWidgets('biometrics: off when the phone has none', (tester) async {
      await _pump(tester, on(biometricsAvailable: false));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SwitchListTile>(_switch('Unlock with fingerprint or face'))
            .onChanged,
        isNull,
      );
      expect(find.text('Not set up on this phone.'), findsOneWidget);
    });
  });

  group('export', () {
    testWidgets('saves every expense and says how many', (tester) async {
      final setup = await _pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export expenses'));
      await tester.pumpAndSettle();

      expect(find.text('Exported 2 expenses.'), findsOneWidget);
      expect(setup.exporter.fileName, 'mizan-expenses-2026-10-06.csv');
    });

    testWidgets('nothing to export', (tester) async {
      final setup = _Setup();
      await setup.expenses.delete('a');
      await setup.expenses.delete('b');
      await _pump(tester, setup);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export expenses'));
      await tester.pumpAndSettle();

      expect(find.text('No expenses to export yet.'), findsOneWidget);
    });

    testWidgets('cancelling says nothing', (tester) async {
      final setup = _Setup()..exporter.saves = false;
      await _pump(tester, setup);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export expenses'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failed write says so', (tester) async {
      final setup = _Setup()
        ..exporter.failure = const SettingsFailure(SettingsError.exportFailed);
      await _pump(tester, setup);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export expenses'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't write the file. Try again."), findsOneWidget);
    });
  });
}
