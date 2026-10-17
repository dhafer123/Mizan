import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/theme/app_colors.dart';
import 'package:mizan/app/theme/app_theme.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/presentation/shared/category_color.dart';
import 'package:mizan/features/expenses/presentation/shared/category_icon.dart';

void main() {
  Future<BuildContext> contextIn(WidgetTester tester, ThemeData theme) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('the colour follows the icon, so it is the same everywhere', (
    tester,
  ) async {
    final context = await contextIn(tester, AppTheme.light());
    const custom = Category(id: 'custom-1', name: 'Café', icon: 'coffee');

    expect(
      categoryColor(context, custom),
      categoryColor(context, DefaultCategories.food),
      reason: 'coffee and food share the amber slot',
    );
    expect(
      categoryColor(context, DefaultCategories.food),
      isNot(categoryColor(context, DefaultCategories.transport)),
    );
  });

  testWidgets('the built-in categories each get their own colour', (
    tester,
  ) async {
    final context = await contextIn(tester, AppTheme.dark());
    final colors = {
      for (final c in DefaultCategories.all) categoryColor(context, c),
    };
    expect(colors, hasLength(DefaultCategories.all.length));
    expect(colors.every(AppColors.dark.categories.contains), isTrue);
  });

  testWidgets('every icon has a colour; unknown ones and none are grey', (
    tester,
  ) async {
    final context = await contextIn(tester, AppTheme.light());
    for (final key in categoryIconKeys) {
      expect(
        categoryColor(context, Category(id: key, name: key, icon: key)),
        isNot(AppColors.light.chartOther),
        reason: key,
      );
    }
    expect(
      categoryColor(context, const Category(id: 'x', name: 'X', icon: 'ufo')),
      AppColors.light.chartOther,
    );
    expect(categoryColor(context, null), AppColors.light.chartOther);
  });
}
