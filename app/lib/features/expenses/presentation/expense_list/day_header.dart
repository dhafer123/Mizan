import 'package:flutter/material.dart';

import '../../../../core/money/money_formatter.dart';
import '../../domain/value_objects/expense_day.dart';

/// A day's date and how much was spent that day.
class DayHeader extends StatelessWidget {
  const DayHeader({required this.day, super.key});

  final ExpenseDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.primary,
    );
    // The day is a calendar date; show it as that date, not as an instant.
    final date = DateTime(day.day.year, day.day.month, day.day.day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              MaterialLocalizations.of(context).formatMediumDate(date),
              style: style,
            ),
          ),
          Text(const MoneyFormatter().format(day.total), style: style),
        ],
      ),
    );
  }
}
