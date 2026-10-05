import '../../../../core/clock/calendar_day.dart';
import '../../../../core/result/result.dart';
import '../entities/income_source.dart';
import '../value_objects/budget_error.dart';
import '../value_objects/budget_failure.dart';
import '../value_objects/income_schedule.dart';

/// Checks an income source before it is saved, and returns it cleaned up:
/// the name trimmed and a one-off date as a calendar day.
class ValidateIncomeSource {
  const ValidateIncomeSource();

  /// Matches the column length in the income sources table.
  static const maxNameLength = 60;

  Result<IncomeSource, BudgetFailure> call(IncomeSource source) {
    Err<IncomeSource, BudgetFailure> fail(BudgetError error) =>
        Err(BudgetFailure(error));

    final name = source.name.trim();
    if (name.isEmpty) return fail(BudgetError.nameEmpty);
    if (name.length > maxNameLength) return fail(BudgetError.nameTooLong);
    if (!source.amount.isPositive) return fail(BudgetError.amountNotPositive);

    final schedule = switch (source.schedule) {
      MonthlyIncome(:final dayOfMonth) when dayOfMonth < 1 || dayOfMonth > 31 =>
        null,
      OneOffIncome(:final date) => IncomeSchedule.oneOff(
        date: date.calendarDay,
      ),
      final other => other,
    };
    if (schedule == null) return fail(BudgetError.invalidDay);

    return Ok(source.copyWith(name: name, schedule: schedule));
  }
}
