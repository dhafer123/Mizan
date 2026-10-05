import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/clock/year_month.dart';
import '../expense_list/selected_month.dart';

/// The month being shown, with arrows to the previous and next month. It
/// can't go past the current month. Screens that show it share the
/// selected month.
class MonthBar extends ConsumerWidget {
  const MonthBar({required this.month, super.key});

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
