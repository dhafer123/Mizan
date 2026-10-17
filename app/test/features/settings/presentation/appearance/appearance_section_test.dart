import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/budget/presentation/home/home_screen.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_error.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_failure.dart';
import 'package:mizan/features/settings/domain/value_objects/theme_choice.dart';

import '../../../../support/app_harness.dart';
import '../../../../support/fake_device_preferences_repository.dart';

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

void main() {
  Future<AppHarness> boot(
    WidgetTester tester,
    FakeDevicePreferencesRepository preferences,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final app = AppHarness(preferences: preferences);
    await app.boot(tester);
    return app;
  }

  Future<void> openThemeDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens in the saved theme', (tester) async {
    final app = await boot(
      tester,
      FakeDevicePreferencesRepository(theme: ThemeChoice.dark, onboarded: true),
    );

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(_brightness(tester), Brightness.dark);

    await app.shutDown(tester);
  });

  testWidgets('a choice in Settings applies at once and is saved', (
    tester,
  ) async {
    final app = await boot(
      tester,
      FakeDevicePreferencesRepository(onboarded: true),
    );
    // The test phone is in light mode, so "Same as the phone" is light.
    expect(_brightness(tester), Brightness.light);

    await openThemeDialog(tester);
    expect(find.text('Same as the phone'), findsNWidgets(2));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(_brightness(tester), Brightness.dark);
    expect(app.preferences.theme, ThemeChoice.dark);
    expect(find.text('Dark'), findsOneWidget, reason: 'the tile shows it');

    await app.shutDown(tester);
  });

  testWidgets('a failed save says so, and still applies until restart', (
    tester,
  ) async {
    final preferences = FakeDevicePreferencesRepository(onboarded: true);
    final app = await boot(tester, preferences);
    preferences.saveFailure = const SettingsFailure(SettingsError.storage);

    await openThemeDialog(tester);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save on this device. Try again."), findsOne);
    expect(_brightness(tester), Brightness.dark);
    expect(preferences.theme, ThemeChoice.system);

    await app.shutDown(tester);
  });
}
