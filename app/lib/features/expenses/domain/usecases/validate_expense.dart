import '../../../../core/clock/calendar_day.dart';
import '../../../../core/clock/clock.dart';
import '../../../../core/result/result.dart';
import '../entities/expense.dart';
import '../value_objects/expense_error.dart';
import '../value_objects/expense_failure.dart';

/// Checks an expense before it is saved, and returns it cleaned up: the date
/// as a calendar day and the note trimmed (blank becomes none).
class ValidateExpense {
  const ValidateExpense(this._clock);

  final Clock _clock;

  static const maxNoteLength = 200;

  Result<Expense, ExpenseFailure> call(Expense expense) {
    Err<Expense, ExpenseFailure> fail(ExpenseError error) =>
        Err(ExpenseFailure(error));

    if (!expense.amount.isPositive) return fail(ExpenseError.amountNotPositive);
    if (expense.categoryId.trim().isEmpty) return fail(ExpenseError.noCategory);

    final note = expense.note?.trim();
    if (note != null && note.length > maxNoteLength) {
      return fail(ExpenseError.noteTooLong);
    }

    final date = expense.date.calendarDay;
    if (date.isAfter(_clock.now().calendarDay)) {
      return fail(ExpenseError.dateInFuture);
    }

    return Ok(
      expense.copyWith(
        categoryId: expense.categoryId.trim(),
        date: date,
        note: note == null || note.isEmpty ? null : note,
      ),
    );
  }
}
