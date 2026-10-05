import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/expenses_providers.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_failure.dart';
import 'package:mizan/features/expenses/presentation/categories/category_sheet.dart';

import '../../../../support/fake_category_repository.dart';
import '../../../../support/sequential_id_generator.dart';

/// Opens the sheet from a button, like the app does, and records what it
/// returned.
class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  final categories = FakeCategoryRepository();
  bool? result;
  var closed = false;

  Future<void> open({Category? category}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          idGeneratorProvider.overrideWithValue(
            SequentialIdGenerator(prefix: 'c'),
          ),
          categoryRepositoryProvider.overrideWithValue(categories),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showCategorySheet(context, category: category);
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

  Future<void> enter(String label, String text) =>
      tester.enterText(field(label), text);

  Future<void> save() async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('new', () {
    testWidgets('creates a category with an icon and a limit', (tester) async {
      final h = _Harness(tester);
      await h.open();
      expect(find.text('New category'), findsOneWidget);

      await h.enter('Name', ' Gym ');
      await tester.tap(find.byKey(const ValueKey('icon-sport')));
      await h.enter('Monthly limit (optional)', '30');
      await h.save();

      expect(h.result, isTrue);
      expect(
        h.categories.categories.last,
        const Category(
          id: 'c1',
          name: 'Gym',
          icon: 'sport',
          monthlyLimit: Money(30000, Currency.tnd),
        ),
      );
    });

    testWidgets('no limit when the field is left empty', (tester) async {
      final h = _Harness(tester);
      await h.open();

      await h.enter('Name', 'Gym');
      await h.save();

      expect(h.categories.categories.last.monthlyLimit, isNull);
      expect(h.categories.categories.last.icon, 'other');
    });

    testWidgets('an empty name', (tester) async {
      final h = _Harness(tester);
      await h.open();

      await h.save();

      expect(find.text('Enter a name.'), findsOneWidget);
      expect(h.closed, isFalse);
      expect(h.categories.categories, DefaultCategories.all);
    });

    testWidgets('a name another category has, cleared on edit', (tester) async {
      final h = _Harness(tester);
      await h.open();

      await h.enter('Name', 'food');
      await h.save();
      expect(
        find.text('Another category already has this name.'),
        findsOneWidget,
      );

      await h.enter('Name', 'Fast food');
      await tester.pump();
      expect(
        find.text('Another category already has this name.'),
        findsNothing,
      );
    });

    testWidgets('a limit that is not an amount', (tester) async {
      final h = _Harness(tester);
      await h.open();

      await h.enter('Name', 'Gym');
      await h.enter('Monthly limit (optional)', 'lots');
      await h.save();

      expect(find.text('"lots" is not a valid amount.'), findsOneWidget);
      expect(h.closed, isFalse);
    });

    testWidgets('a zero limit (a domain rule)', (tester) async {
      final h = _Harness(tester);
      await h.open();

      await h.enter('Name', 'Gym');
      await h.enter('Monthly limit (optional)', '0');
      await h.save();

      expect(find.text('The limit must be more than 0.'), findsOneWidget);
    });

    testWidgets('a storage failure shows, and the form stays', (tester) async {
      final h = _Harness(tester);
      h.categories.writeFailure = const CategoryFailure(CategoryError.storage);
      await h.open();

      await h.enter('Name', 'Gym');
      await h.save();

      expect(
        find.text("Couldn't save on this device. Try again."),
        findsOneWidget,
      );
      expect(h.closed, isFalse);
    });
  });

  group('edit', () {
    testWidgets('starts from the category', (tester) async {
      final h = _Harness(tester);
      final rent = DefaultCategories.rent.copyWith(
        monthlyLimit: const Money(450000, Currency.tnd),
      );
      h.categories.categories[2] = rent;
      await h.open(category: rent);

      expect(find.text('Edit category'), findsOneWidget);
      expect(
        tester.widget<TextField>(h.field('Name')).controller!.text,
        'Rent',
      );
      expect(
        tester
            .widget<TextField>(h.field('Monthly limit (optional)'))
            .controller!
            .text,
        '450.000',
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('icon-rent')))
            .isSelected,
        isTrue,
      );
    });

    testWidgets('renames a default category', (tester) async {
      final h = _Harness(tester);
      await h.open(category: DefaultCategories.food);

      await h.enter('Name', 'Eating out');
      await h.save();

      expect(h.result, isTrue);
      expect(h.categories.byId('food').name, 'Eating out');
    });

    testWidgets('clearing the limit removes it', (tester) async {
      final h = _Harness(tester);
      final rent = DefaultCategories.rent.copyWith(
        monthlyLimit: const Money(450000, Currency.tnd),
      );
      h.categories.categories[2] = rent;
      await h.open(category: rent);

      await h.enter('Monthly limit (optional)', '');
      await h.save();

      expect(h.categories.byId('rent').monthlyLimit, isNull);
    });
  });
}
