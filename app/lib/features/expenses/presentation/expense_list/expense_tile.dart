import 'package:flutter/material.dart';

import '../../../../core/money/money_formatter.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/expense.dart';
import '../shared/category_icon.dart';

/// One expense; swipe it towards the start to delete.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    required this.expense,
    required this.category,
    required this.onTap,
    required this.onDismissed,
    super.key,
  });

  final Expense expense;

  /// Null while categories load, or for a category this device doesn't know.
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final categoryName = category?.name ?? 'Uncategorised';
    final note = expense.note;

    return Dismissible(
      key: ValueKey('dismiss-${expense.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        color: colors.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: ExcludeSemantics(
            child: Icon(categoryIcon(category?.icon ?? '')),
          ),
        ),
        title: Text(note ?? categoryName),
        subtitle: note == null ? null : Text(categoryName),
        trailing: Text(
          const MoneyFormatter().format(expense.amount),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}
