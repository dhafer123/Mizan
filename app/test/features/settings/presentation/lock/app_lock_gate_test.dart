import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/settings_providers.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/features/settings/domain/entities/lock_settings.dart';
import 'package:mizan/features/settings/domain/usecases/unlock_with_biometrics.dart';
import 'package:mizan/features/settings/presentation/lock/app_lock_gate.dart';

import '../../../../support/fake_biometric_authenticator.dart';
import '../../../../support/fake_lock_settings_repository.dart';

const _pin = LockSettings(pin: '2468');
const _locked = 'Mizan is locked';
const _secret = 'Your spending';

class _Setup {
  _Setup(LockSettings? settings, {bool biometricsPass = true})
    : repository = FakeLockSettingsRepository(settings),
      biometrics = FakeBiometricAuthenticator(passes: biometricsPass);

  final clock = FakeClock(DateTime.utc(2026, 10, 6, 9));
  final FakeLockSettingsRepository repository;
  final FakeBiometricAuthenticator biometrics;
}

Future<_Setup> _pump(
  WidgetTester tester,
  LockSettings? settings, {
  bool biometricsPass = true,
}) async {
  final setup = _Setup(settings, biometricsPass: biometricsPass);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(setup.clock),
        lockSettingsRepositoryProvider.overrideWithValue(setup.repository),
        biometricAuthenticatorProvider.overrideWithValue(setup.biometrics),
      ],
      child: MaterialApp(
        builder: (context, child) => AppLockGate(child: child!),
        home: const Scaffold(body: Text(_secret)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return setup;
}

/// Moves the app through [states], one lifecycle step at a time.
void _goThrough(WidgetTester tester, List<AppLifecycleState> states) {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

const _toBackground = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];
const _toForeground = [
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

/// Sends the app to the background for [away], then brings it back.
Future<void> _leaveFor(WidgetTester tester, _Setup setup, Duration away) async {
  _goThrough(tester, _toBackground);
  await tester.pump();
  setup.clock.advance(away);
  _goThrough(tester, _toForeground);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.widgetWithText(TextButton, digit));
    await tester.pump();
  }
  await tester.tap(find.text('Unlock'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with the lock off, the app never locks', (tester) async {
    final setup = await _pump(tester, null);
    expect(find.text(_secret), findsOneWidget);

    await _leaveFor(tester, setup, const Duration(hours: 2));

    expect(find.text(_secret), findsOneWidget);
    expect(find.text(_locked), findsNothing);
  });

  testWidgets('locked at start; the app is hidden until the PIN', (
    tester,
  ) async {
    await _pump(tester, _pin);

    expect(find.text(_locked), findsOneWidget);
    expect(find.text(_secret), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Unlock'))
          .onPressed,
      isNull,
      reason: 'needs at least 4 digits',
    );

    await _enter(tester, '2468');

    expect(find.text(_locked), findsNothing);
    expect(find.text(_secret), findsOneWidget);
  });

  testWidgets('a wrong PIN says so and clears', (tester) async {
    await _pump(tester, _pin);

    await _enter(tester, '1357');

    expect(find.text('Wrong PIN. Try again.'), findsOneWidget);
    expect(find.text(_locked), findsOneWidget);
    expect(find.bySemanticsLabel('0 digits entered'), findsOneWidget);
  });

  testWidgets('five wrong PINs: wait 30 seconds', (tester) async {
    await _pump(tester, _pin);

    for (var i = 0; i < 5; i++) {
      await _enter(tester, '0000');
    }

    expect(
      find.text('Too many wrong PINs. Wait 30 seconds and try again.'),
      findsOneWidget,
    );
  });

  group('on coming back', () {
    Future<_Setup> unlocked(WidgetTester tester) async {
      final setup = await _pump(tester, _pin);
      await _enter(tester, '2468');
      return setup;
    }

    testWidgets('locks after a minute or more in the background', (
      tester,
    ) async {
      final setup = await unlocked(tester);

      await _leaveFor(tester, setup, const Duration(minutes: 1));

      expect(find.text(_locked), findsOneWidget);
      expect(find.text(_secret), findsNothing);

      await _enter(tester, '2468');
      expect(find.text(_secret), findsOneWidget);
    });

    testWidgets('stays open after less than a minute', (tester) async {
      final setup = await unlocked(tester);

      await _leaveFor(tester, setup, const Duration(seconds: 59));

      expect(find.text(_secret), findsOneWidget);
      expect(find.text(_locked), findsNothing);
    });

    testWidgets('time away is counted from the first pause', (tester) async {
      final setup = await unlocked(tester);

      _goThrough(tester, _toBackground);
      setup.clock.advance(const Duration(seconds: 40));
      // Briefly in view (not resumed), then back to the background.
      _goThrough(tester, [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
      ]);
      _goThrough(tester, [AppLifecycleState.hidden, AppLifecycleState.paused]);
      setup.clock.advance(const Duration(seconds: 20));
      _goThrough(tester, _toForeground);
      await tester.pumpAndSettle();

      expect(find.text(_locked), findsOneWidget);
    });
  });

  group('biometrics', () {
    const withBiometrics = LockSettings(pin: '2468', biometrics: true);

    testWidgets('asked for as soon as the lock shows', (tester) async {
      final setup = await _pump(tester, withBiometrics);

      expect(setup.biometrics.reasons, [UnlockWithBiometrics.reason]);
      expect(find.text(_secret), findsOneWidget);
    });

    testWidgets('a failed check leaves the PIN and a retry button', (
      tester,
    ) async {
      final setup = await _pump(tester, withBiometrics, biometricsPass: false);
      expect(find.text(_locked), findsOneWidget);

      setup.biometrics.passes = true;
      await tester.tap(
        find.bySemanticsLabel('Unlock with fingerprint or face'),
      );
      await tester.pumpAndSettle();

      expect(find.text(_secret), findsOneWidget);
    });

    testWidgets('not offered when not turned on', (tester) async {
      final setup = await _pump(tester, _pin);

      expect(setup.biometrics.reasons, isEmpty);
      expect(
        find.bySemanticsLabel('Unlock with fingerprint or face'),
        findsNothing,
      );
    });
  });
}
