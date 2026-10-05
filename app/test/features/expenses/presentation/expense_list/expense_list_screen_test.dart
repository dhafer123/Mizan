import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/expenses_providers.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';
import 'package:mizan/features/expenses/presentation/expense_list/expense_list_screen.dart';

import '../../../../support/fake_category_repository.dart';
import '../../../../support/fake_expense_repository.dart';
import '../../../../support/sequential_id_generator.dart';

Expense _expense(String id, DateTime date, int millimes, {String? note}) =>
    Expense(
      id: id,
      amount: Money(millimes, Currency.tnd),
      categoryId: 'food',
      date: date,
      note: note,
    );

final _coffee = _expense('e2', DateTime.utc(2026, 10, 6), 4500, note: 'coffee');
final _lunch = _expense('e3', DateTime.utc(2026, 10, 6), 12000);
final _books = _expense('e1', DateTime.utc(2026, 10, 2), 30000, note: 'books');
final _september = _expense('e0', DateTime.utc(2026, 9, 28), 8000, note: 'bus');

Future<FakeExpenseRepository> _pump(
  WidgetTester tester, {
  List<Expense>? expenses,
  ExpenseFailure? watchFailure,
}) async {
  final repository = FakeExpenseRepository(
    expenses ?? [_coffee, _lunch, _books, _september],
  )..watchFailure = watchFailure;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(
          FakeClock(DateTime.utc(2026, 10, 6, 9)),
        ),
        idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
        expenseRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
      ],
      child: const MaterialApp(home: ExpenseListScreen()),
    ),
  );
  return repository;
}

Future<void> _swipeAway(WidgetTester tester, String text) async {
  await tester.drag(find.text(text), const Offset(-600, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loading, then the month grouped by day', (tester) async {
    await _pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
    // Newest day first, each with its total.
    final tue = tester.getTopLeft(find.text('Tue, Oct 6')).dy;
    final fri = tester.getTopLeft(find.text('Fri, Oct 2')).dy;
    expect(tue, lessThan(fri));
    expect(find.text('16.500 DT'), findsOneWidget); // 4.500 + 12.000
    expect(find.text('30.000 DT'), findsNWidgets(2)); // day total and row
    // A note is the title; without one the category is.
    expect(find.widgetWithText(ListTile, 'coffee'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Food'), findsWidgets);
    expect(find.text('bus'), findsNothing); // September
  });

  testWidgets('an empty month', (tester) async {
    await _pump(tester, expenses: []);
    await tester.pumpAndSettle();

    expect(find.text('No expenses this month'), findsOneWidget);
  });

  testWidgets('a failure shows its message and can be retried', (tester) async {
    final repository = await _pump(
      tester,
      watchFailure: const ExpenseFailure(ExpenseError.storage),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save on this device. Try again."),
      findsOneWidget,
    );

    repository.watchFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('coffee'), findsOneWidget);
  });

  testWidgets('moves between months, but not past the current one', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    final next = find.widgetWithIcon(IconButton, Icons.chevron_right);
    expect(tester.widget<IconButton>(next).onPressed, isNull);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('bus'), findsOneWidget);
    expect(find.text('coffee'), findsNothing);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('No expenses this month'), findsOneWidget);

    await tester.tap(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
  });

  group('swipe to delete', () {
    testWidgets('undo brings it back and deletes nothing', (tester) async {
      final repository = await _pump(tester);
      await tester.pumpAndSettle();

      await _swipeAway(tester, 'coffee');
      expect(find.text('coffee'), findsNothing);
      expect(find.text('Expense deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('coffee'), findsOneWidget);
      expect(repository.deleted, isEmpty);
    });

    testWidgets('without undo, it is deleted when the snackbar closes', (
      tester,
    ) async {
      final repository = await _pump(tester);
      await tester.pumpAndSettle();

      await _swipeAway(tester, 'coffee');
      expect(repository.deleted, isEmpty);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(repository.deleted, ['e2']);
      expect(find.text('coffee'), findsNothing);
      expect(find.text('Expense deleted'), findsNothing);
    });

    testWidgets('the last expense of a day takes its header with it', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      await _swipeAway(tester, 'books');

      expect(find.text('Fri, Oct 2'), findsNothing);
    });

    testWidgets('a second swipe commits the first', (tester) async {
      final repository = await _pump(tester);
      await tester.pumpAndSettle();

      await _swipeAway(tester, 'coffee');
      await _swipeAway(tester, 'books');

      expect(repository.deleted, ['e2']);
      expect(find.text('Expense deleted'), findsOneWidget);
    });

    testWidgets('a failed delete shows the message and the expense', (
      tester,
    ) async {
      final repository = await _pump(tester);
      await tester.pumpAndSettle();
      repository.writeFailure = const ExpenseFailure(ExpenseError.storage);

      await _swipeAway(tester, 'coffee');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't save on this device. Try again."),
        findsOneWidget,
      );
      expect(find.text('coffee'), findsOneWidget);
    });
  });

  testWidgets('tapping an expense opens it for editing', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('coffee'));
    await tester.pumpAndSettle();

    expect(find.text('Edit expense'), findsOneWidget);
  });

  testWidgets('the add button opens an empty sheet', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add expense'), findsOneWidget);
  });
}
