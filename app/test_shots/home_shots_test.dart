// Visual check, not a test suite: renders the tabs with the real fonts and
// real shadows to PNGs in test_shots/shots/ (git-ignored), to look at UI
// changes in both themes. Not run by CI (outside test/).
// Run from app/: flutter test test_shots --update-goldens
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/budget_providers.dart';
import 'package:mizan/app/di/expenses_providers.dart';
import 'package:mizan/app/router/app_router.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/settings/domain/value_objects/theme_choice.dart';
import 'package:mizan/features/settings/presentation/appearance/theme_choice_controller.dart';

import '../test/support/app_harness.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final bytes = File(p).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Manrope', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
      'assets/fonts/Manrope-$w.ttf',
  ]);
  await load('MaterialIcons', [
    'C:/flutter_windows_3.13.9-stable/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
}

Money _dt(int d) => Money(d * 1000, Currency.tnd);

Future<void> _seed(
  WidgetTester tester,
  AppHarness app, {
  bool tight = false,
}) async {
  var done = false;
  unawaited(() async {
    final c = app.container;
    await c.read(addIncomeSourceProvider)(
      name: 'Grant',
      amount: _dt(tight ? 300 : 600),
      schedule: const IncomeSchedule.monthly(dayOfMonth: 15),
    );
    await c.read(setMonthlyBudgetProvider)(
      const YearMonth(2026, 10),
      totalLimit: _dt(500),
    );
    await c.read(editCategoryProvider)(
      DefaultCategories.food.copyWith(monthlyLimit: _dt(100)),
    );
    for (final (cat, d, note, day) in [
      ('food', 85, 'Groceries', 6),
      ('transport', 25, 'Taxi', 5),
      ('rent', 150, null, 1),
      ('study', 30, 'Printing', 4),
      ('leisure', 12, 'Cinema', 3),
      for (var i = 1; i <= 20; i++) ('food', tight ? 9 : 4, 'Coffee', 1),
    ]) {
      await c.read(addExpenseProvider)(
        amount: _dt(d),
        categoryId: cat,
        date: DateTime.utc(2026, 10, day),
        note: note,
      );
    }
    done = true;
  }());
  for (var i = 0; i < 300 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final theme in [ThemeChoice.light, ThemeChoice.dark]) {
    for (final tight in [false, true]) {
      for (final route in [
        AppRoutes.home,
        AppRoutes.expenses,
        AppRoutes.budget,
      ]) {
        final name =
            '${theme.name}_${tight ? 'tight' : 'ok'}_${route.replaceAll('/', '') == '' ? 'home' : route.replaceAll('/', '')}';
        testWidgets(name, (tester) async {
          // Real shadows, not the test mode's solid outlines.
          debugDisableShadows = false;
          tester.view
            ..physicalSize = Size(1080, route == AppRoutes.home ? 3900 : 2340)
            ..devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          final app = AppHarness();
          await app.boot(tester);
          await _seed(tester, app, tight: tight);
          await app.container
              .read(themeChoiceControllerProvider.notifier)
              .choose(theme);
          app.container.read(appRouterProvider).go(route);
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('shots/$name.png'),
          );
          debugDisableShadows = true;
          await app.shutDown(tester);
        });
      }
    }
  }
}
