import '../../domain/value_objects/expense_day.dart';

/// [days] without the expenses in [ids]; days left empty are dropped.
List<ExpenseDay> hideExpenses(List<ExpenseDay> days, Set<String> ids) {
  if (ids.isEmpty) return days;
  return [
    for (final day in days)
      if (day.expenses.where((e) => !ids.contains(e.id)).toList()
          case final left when left.isNotEmpty)
        day.copyWith(expenses: left),
  ];
}
