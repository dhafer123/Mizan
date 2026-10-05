import '../../../../core/clock/year_month.dart';
import '../../../../core/result/result.dart';
import '../entities/expense.dart';
import '../repositories/expense_repository.dart';
import '../value_objects/expense_day.dart';
import '../value_objects/expense_failure.dart';

/// A month's expenses grouped by day: newest day first, and newest first
/// within a day.
///
/// Within a day, "newest" is by id: ids are UUIDv7, which sort by creation
/// time. That is only for display; sync never orders by id or device time.
class WatchMonthExpenses {
  const WatchMonthExpenses(this._repository);

  final ExpenseRepository _repository;

  Stream<Result<List<ExpenseDay>, ExpenseFailure>> call(YearMonth month) =>
      _repository.watchMonth(month).map((result) => result.map(_byDay));

  static List<ExpenseDay> _byDay(List<Expense> expenses) {
    final sorted = [...expenses]
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });

    final days = <ExpenseDay>[];
    var current = <Expense>[];
    for (final expense in sorted) {
      if (current.isNotEmpty && current.first.date != expense.date) {
        days.add(ExpenseDay(day: current.first.date, expenses: current));
        current = [];
      }
      current.add(expense);
    }
    if (current.isNotEmpty) {
      days.add(ExpenseDay(day: current.first.date, expenses: current));
    }
    return List.unmodifiable(days);
  }
}
