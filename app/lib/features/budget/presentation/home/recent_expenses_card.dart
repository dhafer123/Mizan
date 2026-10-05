import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/clock/calendar_day.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../expenses/domain/entities/category.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/presentation/expense_sheet/expense_sheet.dart';
import '../../../expenses/presentation/shared/categories_provider.dart';
import '../../../expenses/presentation/shared/category_icon.dart';

/// The newest expenses; tap one to edit it, or see them all.
class RecentExpensesCard extends ConsumerWidget {
  const RecentExpensesCard({required this.expenses, super.key});

  /// Newest first.
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? <Category>[])
        c.id: c,
    };
    final today = ref.watch(clockProvider).now().calendarDay;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent expenses',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.expenses),
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('No expenses yet. Tap "Add expense" to log one.'),
            )
          else
            for (final expense in expenses)
              _RecentTile(
                expense: expense,
                category: categories[expense.categoryId],
                today: today,
              ),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.expense,
    required this.category,
    required this.today,
  });

  final Expense expense;
  final Category? category;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final categoryName = category?.name ?? 'Uncategorised';
    final note = expense.note;
    return ListTile(
      onTap: () => showExpenseSheet(context, expense: expense),
      leading: CircleAvatar(
        child: ExcludeSemantics(
          child: Icon(categoryIcon(category?.icon ?? '')),
        ),
      ),
      title: Text(note ?? categoryName),
      subtitle: Text(
        note == null
            ? _dayLabel(context)
            : '$categoryName · ${_dayLabel(context)}',
      ),
      trailing: Text(
        const MoneyFormatter().format(expense.amount),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }

  String _dayLabel(BuildContext context) {
    final day = expense.date;
    return switch (today.difference(day).inDays) {
      0 => 'Today',
      1 => 'Yesterday',
      // A calendar date; show it as that date, not as an instant.
      _ => MaterialLocalizations.of(
        context,
      ).formatMediumDate(DateTime(day.year, day.month, day.day)),
    };
  }
}
