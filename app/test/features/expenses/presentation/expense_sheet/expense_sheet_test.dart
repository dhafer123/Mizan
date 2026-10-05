import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/expenses_providers.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';
import 'package:mizan/features/expenses/presentation/expense_sheet/expense_sheet.dart';

import '../../../../support/fake_category_repository.dart';
import '../../../../support/fake_expense_repository.dart';
import '../../../../support/sequential_id_generator.dart';

final _today = DateTime.utc(2026, 10, 6);

final _coffee = Expense(
  id: 'e0',
  amount: const Money(4500, Currency.tnd),
  categoryId: 'food',
  date: DateTime.utc(2026, 10, 3),
  note: 'coffee',
);

/// Opens the sheet from a button, like the app does, and records what it
/// returned.
class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  final expenses = FakeExpenseRepository([_coffee]);
  final categories = FakeCategoryRepository();
  bool? result;
  var closed = false;

  Future<void> open({Expense? expense}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(
            FakeClock(_today.add(const Duration(hours: 9))),
          ),
          idGeneratorProvider.overrideWithValue(
            SequentialIdGenerator(prefix: 'e'),
          ),
          expenseRepositoryProvider.overrideWithValue(expenses),
          categoryRepositoryProvider.overrideWithValue(categories),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showExpenseSheet(context, expense: expense);
                  closed = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> enterAmount(String text) =>
      tester.enterText(field('Amount'), text);

  Future<void> pickCategory(String name) async {
    await tester.tap(find.widgetWithText(ChoiceChip, name));
    await tester.pump();
  }

  Future<void> save() async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('add', () {
    testWidgets('shows an empty form dated today, with the categories', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.open();

      expect(find.text('Add expense'), findsOneWidget);
      expect(find.text('Tue, Oct 6'), findsOneWidget);
      expect(find.text('DT'), findsOneWidget);
      for (final category in DefaultCategories.all) {
        expect(find.widgetWithText(ChoiceChip, category.name), findsOneWidget);
      }
      final amount = tester.widget<TextField>(h.field('Amount'));
      expect(amount.controller!.text, isEmpty);
    });

    testWidgets('saves a valid expense and closes', (tester) async {
      final h = _Harness(tester);
      await h.open();

      await h.enterAmount('4,5');
      await h.pickCategory('Transport');
      await tester.enterText(h.field('Note (optional)'), ' taxi ');
      await h.save();

      expect(h.closed, isTrue);
      expect(h.result, isTrue);
      expect(
        h.expenses.live,
        contains(
          Expense(
            id: 'e1',
            amount: const Money(4500, Currency.tnd),
            categoryId: 'transport',
            date: _today,
            note: 'taxi',
          ),
        ),
      );
    });

    testWidgets('no amount', (tester) async {
      final h = _Harness(tester);
      await h.open();

      await h.pickCategory('Food');
      await h.save();

      expect(find.text('Enter an amount.'), findsOneWidget);
      expect(h.closed, isFalse);
      expect(h.expenses.live, [_coffee]);
    });

    testWidgets('an amount that is not a number', (tester) async {
      final h = _Harness(tester);
      await h.open();

      await h.enterAmount('abc');
      await h.save();

      expect(find.text('"abc" is not a valid amount.'), findsOneWidget);
      expect(h.closed, isFalse);
    });

    testWidgets('more decimals than the currency has', (tester) async {
      final h = _Harness(tester);
      await h.open();

      await h.enterAmount('4.5555');
      await h.save();

      expect(find.text('TND amounts have at most 3 decimals.'), findsOneWidget);
    });

    testWidgets('a zero or negative amount (a domain rule)', (tester) async {
      final h = _Harness(tester);
      await h.open();
      await h.pickCategory('Food');

      await h.enterAmount('0');
      await h.save();
      expect(find.text('The amount must be more than 0.'), findsOneWidget);

      await h.enterAmount('-3');
      await h.save();
      expect(find.text('The amount must be more than 0.'), findsOneWidget);
      expect(h.closed, isFalse);
      expect(h.expenses.live, [_coffee]);
    });

    testWidgets('no category, cleared once one is picked', (tester) async {
      final h = _Harness(tester);
      await h.open();

      await h.enterAmount('4.5');
      await h.save();
      expect(find.text('Pick a category.'), findsOneWidget);
      expect(h.closed, isFalse);

      await h.pickCategory('Food');
      expect(find.text('Pick a category.'), findsNothing);
      await h.save();
      expect(h.closed, isTrue);
    });

    testWidgets('an amount error clears as soon as the amount is edited', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.open();

      await h.save();
      expect(find.text('Enter an amount.'), findsOneWidget);

      await h.enterAmount('4');
      await tester.pump();
      expect(find.text('Enter an amount.'), findsNothing);
    });

    testWidgets('a selected chip keeps its icon (no checkmark)', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.open();

      await h.pickCategory('Food');

      final food = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Food'),
      );
      expect(food.selected, isTrue);
      expect(food.showCheckmark, isFalse);
    });

    testWidgets('a fixed error is cleared on the next save', (tester) async {
      final h = _Harness(tester);
      await h.open();
      await h.pickCategory('Food');

      await h.save();
      expect(find.text('Enter an amount.'), findsOneWidget);

      await h.enterAmount('12');
      await h.save();
      expect(find.text('Enter an amount.'), findsNothing);
      expect(h.result, isTrue);
    });

    testWidgets('a storage failure shows, and the form stays', (tester) async {
      final h = _Harness(tester);
      h.expenses.writeFailure = const ExpenseFailure(ExpenseError.storage);
      await h.open();

      await h.enterAmount('4.5');
      await h.pickCategory('Food');
      await h.save();

      expect(
        find.text("Couldn't save on this device. Try again."),
        findsOneWidget,
      );
      expect(h.closed, isFalse);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    });

    testWidgets('categories that fail to load show a message', (tester) async {
      final h = _Harness(tester);
      h.categories.failure = const ExpenseFailure(ExpenseError.storage);
      await h.open();

      expect(
        find.text("Couldn't save on this device. Try again."),
        findsOneWidget,
      );
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });

  group('edit', () {
    testWidgets('starts from the expense', (tester) async {
      final h = _Harness(tester);
      await h.open(expense: _coffee);

      expect(find.text('Edit expense'), findsOneWidget);
      final amount = tester.widget<TextField>(h.field('Amount'));
      expect(amount.controller!.text, '4.500');
      expect(find.text('coffee'), findsOneWidget);
      expect(find.text('Sat, Oct 3'), findsOneWidget);
      final food = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Food'),
      );
      expect(food.selected, isTrue);
    });

    testWidgets('saves the changes to the same expense', (tester) async {
      final h = _Harness(tester);
      await h.open(expense: _coffee);

      await h.enterAmount('5');
      await h.pickCategory('Leisure');
      await h.save();

      expect(h.result, isTrue);
      expect(h.expenses.live, [
        _coffee.copyWith(
          amount: const Money(5000, Currency.tnd),
          categoryId: 'leisure',
        ),
      ]);
    });

    testWidgets('validates like add', (tester) async {
      final h = _Harness(tester);
      await h.open(expense: _coffee);

      await h.enterAmount('');
      await h.save();

      expect(find.text('Enter an amount.'), findsOneWidget);
      expect(h.expenses.live, [_coffee]);
    });

    testWidgets('keeps an archived category the expense is in', (tester) async {
      final h = _Harness(tester);
      h.categories.categories.add(
        const Category(id: 'c1', name: 'Coffee', icon: 'food', archived: true),
      );
      h.categories.categories.add(
        const Category(id: 'c2', name: 'Old', icon: 'other', archived: true),
      );
      await h.open(expense: _coffee.copyWith(categoryId: 'c1'));

      expect(find.widgetWithText(ChoiceChip, 'Coffee'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Old'), findsNothing);
    });
  });
}
