import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';
import '../entities/expense.dart';

part 'expense_day.freezed.dart';

/// The expenses of one calendar day, newest first.
@freezed
abstract class ExpenseDay with _$ExpenseDay {
  const factory ExpenseDay({
    required DateTime day,

    /// Never empty; all in one currency.
    required List<Expense> expenses,
  }) = _ExpenseDay;

  const ExpenseDay._();

  /// Computed from the rows, never stored.
  Money get total =>
      Money.sum(expenses.map((e) => e.amount), expenses.first.amount.currency);
}
