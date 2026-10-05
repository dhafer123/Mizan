import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/clock/year_month.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/expense.dart';
import '../../domain/value_objects/expense_day.dart';
import '../expense_sheet/expense_sheet.dart';
import '../shared/categories_provider.dart';
import '../shared/failure_message.dart';
import 'day_header.dart';
import 'expense_tile.dart';
import 'hide_expenses.dart';
import 'month_expenses_provider.dart';
import 'pending_deletes.dart';
import 'selected_month.dart';

/// A month of expenses grouped by day. Tap to edit, swipe to delete (with
/// undo), and the button to add.
class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final days = ref.watch(monthExpensesProvider(month));
    final hidden = ref.watch(pendingDeletesProvider);
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? <Category>[])
        c.id: c,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.categories),
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Categories',
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthBar(month: month),
          const Divider(height: 1),
          Expanded(
            child: days.when(
              data: (all) {
                final visible = hideExpenses(all, hidden);
                return visible.isEmpty
                    ? const _EmptyMonth()
                    : _DayList(days: visible, categories: categories);
              },
              error: (error, _) => _LoadError(
                message: failureMessage(error),
                onRetry: () => ref.invalidate(monthExpensesProvider(month)),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}

class _MonthBar extends ConsumerWidget {
  const _MonthBar({required this.month});

  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.read(selectedMonthProvider.notifier);
    final isCurrent = month.compareTo(selected.current) >= 0;
    final label = MaterialLocalizations.of(
      context,
    ).formatMonthYear(DateTime(month.year, month.month));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: selected.previous,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: isCurrent ? null : selected.next,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
          ),
        ],
      ),
    );
  }
}

class _DayList extends ConsumerWidget {
  const _DayList({required this.days, required this.categories});

  final List<ExpenseDay> days;
  final Map<String, Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <Object>[
      for (final day in days) ...[day, ...day.expenses],
    ];
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88), // clear of the add button
      itemCount: rows.length,
      itemBuilder: (context, index) => switch (rows[index]) {
        final ExpenseDay day => DayHeader(key: ValueKey(day.day), day: day),
        final Expense expense => ExpenseTile(
          key: ValueKey(expense.id),
          expense: expense,
          category: categories[expense.categoryId],
          onTap: () => showExpenseSheet(context, expense: expense),
          onDismissed: () => _deleteWithUndo(context, ref, expense),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  void _deleteWithUndo(BuildContext context, WidgetRef ref, Expense expense) {
    final pending = ref.read(pendingDeletesProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    pending.hide(expense.id);
    // Closing an earlier undo snackbar commits that delete.
    messenger.hideCurrentSnackBar();
    messenger
        .showSnackBar(
          SnackBar(
            content: const Text('Expense deleted'),
            // A snackbar with an action stays up until tapped by default.
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => pending.undo(expense.id),
            ),
          ),
        )
        .closed
        .then((reason) async {
          if (reason == SnackBarClosedReason.action) return;
          final result = await pending.commit(expense.id);
          if (result case Err(:final failure)) {
            messenger.showSnackBar(SnackBar(content: Text(failure.message)));
          }
        });
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 56),
            const SizedBox(height: 16),
            Text('No expenses this month', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap Add to record what you spend.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
