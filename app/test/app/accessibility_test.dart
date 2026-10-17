import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

import '../support/app_harness.dart';

/// Every main screen, in both themes and at normal and double text size,
/// against Flutter's accessibility guidelines: text contrast (WCAG AA),
/// 48×48 tap targets, a label on everything tappable, and (by failing on
/// any overflow) layouts that hold up at 200% text.
///
/// Group screens need an account and are left out here.
const _screens = {
  'home': AppRoutes.home,
  'expenses': AppRoutes.expenses,
  'budget': AppRoutes.budget,
  'income': AppRoutes.income,
  'categories': AppRoutes.categories,
  'groups (signed out)': AppRoutes.groups,
  'settings': AppRoutes.settings,
  'onboarding': AppRoutes.welcome,
};

const _timeout = Timeout(Duration(minutes: 2));

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

/// A month that shows every state colour: a category at 80%+ (warning),
/// one over its limit (error), income, a budget and recent expenses.
Future<void> _seed(ProviderContainer container) async {
  final today = DateTime.utc(2026, 10, 6);
  await container.read(addIncomeSourceProvider)(
    name: 'Grant',
    amount: _dt(600),
    schedule: const IncomeSchedule.monthly(dayOfMonth: 15),
  );
  await container.read(setMonthlyBudgetProvider)(
    YearMonth.of(today),
    totalLimit: _dt(500),
  );
  await container.read(editCategoryProvider)(
    DefaultCategories.food.copyWith(monthlyLimit: _dt(100)),
  );
  await container.read(editCategoryProvider)(
    DefaultCategories.transport.copyWith(monthlyLimit: _dt(20)),
  );
  for (final (category, dinars, note) in [
    ('food', 85, 'Groceries for the week'),
    ('transport', 25, 'Taxi'),
    ('rent', 250, null),
    ('study', 30, 'Printing'),
    ('leisure', 12, 'Cinema'),
    ('other', 4, null),
  ]) {
    await container.read(addExpenseProvider)(
      amount: _dt(dinars),
      categoryId: category,
      date: today,
      note: note,
    );
  }
}

/// Runs [work] (database writes) to the end. Drift's timers run in the
/// test's fake time, so they need pumping rather than `runAsync`.
Future<void> _drive(WidgetTester tester, Future<void> Function() work) async {
  var done = false;
  Object? error;
  unawaited(
    work().then(
      (_) => done = true,
      onError: (Object e) {
        error = e;
        done = true;
      },
    ),
  );
  for (var i = 0; i < 500 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  if (error case final error?) throw error;
  expect(done, isTrue, reason: 'seeding finished');
}

Future<void> _check(
  WidgetTester tester,
  ProviderContainer container,
  String route,
) async {
  container.read(appRouterProvider).go(route);
  await tester.pumpAndSettle();

  for (final theme in [ThemeChoice.light, ThemeChoice.dark]) {
    await container.read(themeChoiceControllerProvider.notifier).choose(theme);
    for (final scale in [1.0, 2.0]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpAndSettle();
      final where = '$route, ${theme.name}, text ×$scale';

      await expectLater(
        tester,
        meetsGuideline(textContrastGuideline),
        reason: where,
      );
      await expectLater(
        tester,
        meetsGuideline(labeledTapTargetGuideline),
        reason: where,
      );
      await expectLater(
        tester,
        meetsGuideline(androidTapTargetGuideline),
        reason: where,
      );
    }
  }
}

void main() {
  Future<AppHarness> boot(WidgetTester tester) async {
    // A typical phone: 360×780 logical pixels.
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final app = AppHarness();
    await app.boot(tester);
    return app;
  }

  for (final MapEntry(key: name, value: route) in _screens.entries) {
    testWidgets('$name, empty', timeout: _timeout, (tester) async {
      final app = await boot(tester);
      await _check(tester, app.container, route);
      await app.shutDown(tester);
    });

    testWidgets('$name, with data', timeout: _timeout, (tester) async {
      final app = await boot(tester);
      await _drive(tester, () => _seed(app.container));
      await tester.pumpAndSettle();
      await _check(tester, app.container, route);
      await app.shutDown(tester);
    });
  }
}
