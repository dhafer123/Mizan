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
import 'package:mizan/features/expenses/presentation/categories/categories_screen.dart';

import '../../../../support/fake_category_repository.dart';
import '../../../../support/sequential_id_generator.dart';

const _gym = Category(id: 'c1', name: 'Gym', icon: 'sport', archived: true);

Future<FakeCategoryRepository> _pump(
  WidgetTester tester, {
  List<Category>? categories,
  CategoryFailure? failure,
}) async {
  final repository = FakeCategoryRepository(
    categories ?? [...DefaultCategories.all, _gym],
  )..failure = failure;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
        categoryRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: CategoriesScreen()),
    ),
  );
  return repository;
}

void main() {
  testWidgets('loading, then active categories, then archived ones', (
    tester,
  ) async {
    await _pump(
      tester,
      categories: [
        DefaultCategories.food.copyWith(
          monthlyLimit: const Money(150000, Currency.tnd),
        ),
        ...DefaultCategories.all.skip(1),
        _gym,
      ],
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    for (final category in DefaultCategories.all) {
      expect(find.byTooltip('Archive ${category.name}'), findsOneWidget);
    }
    expect(find.text('Limit 150.000 DT a month'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
    final archivedHeader = tester.getTopLeft(find.text('Archived')).dy;
    expect(tester.getTopLeft(find.text('Gym')).dy, greaterThan(archivedHeader));
    expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
  });

  testWidgets('no archived section when nothing is archived', (tester) async {
    await _pump(tester, categories: DefaultCategories.all);
    await tester.pumpAndSettle();

    expect(find.text('Archived'), findsNothing);
  });

  testWidgets('a failure shows its message and can be retried', (tester) async {
    final repository = await _pump(
      tester,
      failure: const CategoryFailure(CategoryError.storage),
    );
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't save on this device. Try again."),
      findsOneWidget,
    );

    repository.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
  });

  testWidgets('archive moves a category down, and undo brings it back', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Archive Food'));
    await tester.pumpAndSettle();

    expect(repository.byId('food').archived, isTrue);
    expect(find.text('Food archived'), findsOneWidget);
    expect(find.byTooltip('Archive Food'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Restore'), findsNWidgets(2));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.byId('food').archived, isFalse);
    expect(find.byTooltip('Archive Food'), findsOneWidget);
  });

  testWidgets('restore brings an archived category back', (tester) async {
    final repository = await _pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pumpAndSettle();

    expect(repository.byId('c1').archived, isFalse);
    expect(find.byTooltip('Archive Gym'), findsOneWidget);
    expect(find.text('Archived'), findsNothing);
  });

  testWidgets('the last active category can not be archived', (tester) async {
    final repository = await _pump(
      tester,
      categories: [DefaultCategories.food, _gym],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Archive Food'));
    await tester.pumpAndSettle();

    expect(find.text('Keep at least one category.'), findsOneWidget);
    expect(repository.byId('food').archived, isFalse);
  });

  testWidgets('a failed restore shows why', (tester) async {
    await _pump(
      tester,
      categories: [
        ...DefaultCategories.all,
        const Category(id: 'c1', name: 'Food', icon: 'food', archived: true),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pumpAndSettle();

    expect(
      find.text('Another category already has this name.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a category opens it for editing', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();

    expect(find.text('Edit category'), findsOneWidget);
  });

  testWidgets('the add button opens an empty sheet', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.text('Edit category'), findsNothing);
  });
}
