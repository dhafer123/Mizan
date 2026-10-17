import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/auth/presentation/login/login_screen.dart';
import 'package:mizan/features/budget/presentation/home/home_screen.dart';
import 'package:mizan/features/settings/presentation/onboarding/onboarding_screen.dart';

import '../../../../support/app_harness.dart';
import '../../../../support/fake_device_preferences_repository.dart';

void main() {
  Future<AppHarness> boot(WidgetTester tester, {bool onboarded = false}) async {
    // Tall enough that each step's buttons are on screen.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final app = AppHarness(
      preferences: FakeDevicePreferencesRepository(onboarded: onboarded),
    );
    await app.boot(tester);
    return app;
  }

  Future<void> next(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await tester.pumpAndSettle();
  }

  testWidgets('a new install opens on onboarding', (tester) async {
    final app = await boot(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Welcome to Mizan'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);

    await app.shutDown(tester);
  });

  testWidgets('set up income and a budget, then land on a filled-in Home', (
    tester,
  ) async {
    final app = await boot(tester);

    await next(tester, 'Get started');
    expect(find.text('Your income'), findsOneWidget);
    await tester.tap(find.text('Add income'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Grant');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '600');
    await tester.enterText(
      find.widgetWithText(TextField, 'Day of the month'),
      '15',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Grant'), findsOneWidget);
    expect(find.textContaining('monthly, on day 15'), findsOneWidget);

    await next(tester, 'Next');
    expect(find.text('A monthly budget'), findsOneWidget);
    await tester.tap(find.text('Set a budget'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Spend at most'),
      '450',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('450'), findsOneWidget);
    expect(find.text('Change budget'), findsOneWidget);

    await next(tester, 'Next');
    expect(find.text('Share costs? (optional)'), findsOneWidget);
    // Signed out: groups need an account first.
    expect(find.text('Sign in'), findsOneWidget);

    await next(tester, 'Done');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(app.preferences.onboarded, isTrue);
    expect(find.textContaining('of your'), findsOneWidget, reason: 'budget');
    expect(find.textContaining('Grant'), findsOneWidget, reason: 'income');

    await app.shutDown(tester);
  });

  testWidgets('saved through the same use cases, so they queue for sync', (
    tester,
  ) async {
    final app = await boot(tester);

    await next(tester, 'Get started');
    await tester.tap(find.text('Add income'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Job');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '200');
    await tester.tap(find.text('Irregular'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final ops = await tester.runAsync(() => app.db.select(app.db.outbox).get());
    expect(ops, hasLength(1));
    expect(ops!.single.entity, 'income_sources');

    await app.shutDown(tester);
  });

  testWidgets('Skip setup goes Home and never shows it again', (tester) async {
    final app = await boot(tester);

    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(app.preferences.onboarded, isTrue);

    await app.shutDown(tester);
  });

  testWidgets('Back and the system back button walk back through the steps', (
    tester,
  ) async {
    final app = await boot(tester);

    await next(tester, 'Get started');
    await next(tester, 'Next');
    expect(find.text('Step 3 of 4'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 4'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await app.shutDown(tester);
  });

  testWidgets('Sign in on the last step opens the login screen', (
    tester,
  ) async {
    final app = await boot(tester);

    await next(tester, 'Get started');
    await next(tester, 'Next');
    await next(tester, 'Next');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    await app.shutDown(tester);
  });

  // An install that already has data skips it too: see
  // test/features/settings/domain/usecases/needs_onboarding_test.dart.
  testWidgets('an onboarded install opens on Home', (tester) async {
    final app = await boot(tester, onboarded: true);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    await app.shutDown(tester);
  });
}
