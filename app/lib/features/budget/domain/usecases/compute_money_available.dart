import '../../../../core/clock/calendar_day.dart';
import '../../../../core/clock/year_month.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../groups/domain/value_objects/group_share.dart';
import '../entities/income_source.dart';
import '../value_objects/income_schedule.dart';
import '../value_objects/money_available.dart';
import '../value_objects/next_income.dart';

/// A month's expected income against its spending (personal expenses plus
/// my shares of group expenses), and when money comes in next. What others
/// owe me is not income: it's shown apart.
///
/// Income for a month: every monthly source, every irregular source (its
/// amount is a monthly estimate), and one-off sources dated in the month.
/// There is no carry-over from earlier months.
class ComputeMoneyAvailable {
  const ComputeMoneyAvailable();

  MoneyAvailable call({
    required YearMonth month,
    required Currency currency,
    required List<IncomeSource> incomes,

    /// May include other months; only [month]'s count.
    required List<Expense> expenses,

    /// For the next income; read in its own time zone.
    required DateTime today,

    /// My shares of group expenses; only [month]'s count.
    List<GroupShare> shares = const [],
  }) {
    final income = Money.sum([
      for (final source in incomes)
        if (_paysIn(source.schedule, month)) source.amount,
    ], currency);
    final spent = Money.sum([
      for (final expense in expenses)
        if (month.contains(expense.date)) expense.amount,
      for (final share in shares)
        if (month.contains(share.date)) share.amount,
    ], currency);
    return MoneyAvailable(
      income: income,
      spent: spent,
      next: nextIncome(incomes, today: today),
    );
  }

  /// The source that pays soonest on or after [today] (so "today" on a
  /// payday). Ties go to the name, then the id. Null if nothing is
  /// scheduled: irregular sources have no date.
  static NextIncome? nextIncome(
    List<IncomeSource> incomes, {
    required DateTime today,
  }) {
    final day = today.calendarDay;
    NextIncome? best;
    for (final source in incomes) {
      final date = switch (source.schedule) {
        MonthlyIncome(:final dayOfMonth) => _nextMonthly(dayOfMonth, day),
        OneOffIncome(:final date) => date.isBefore(day) ? null : date,
        IrregularIncome() => null,
      };
      if (date == null) continue;
      if (best == null || _before(date, source, best)) {
        best = NextIncome(source: source, date: date);
      }
    }
    return best;
  }

  /// The day a monthly source pays in [month]: [dayOfMonth], or the month's
  /// last day if it is shorter.
  static DateTime monthlyPayday(int dayOfMonth, YearMonth month) {
    final lastDay = month.endExclusive.subtract(const Duration(days: 1)).day;
    return DateTime.utc(
      month.year,
      month.month,
      dayOfMonth < lastDay ? dayOfMonth : lastDay,
    );
  }

  static bool _paysIn(IncomeSchedule schedule, YearMonth month) =>
      switch (schedule) {
        MonthlyIncome() || IrregularIncome() => true,
        OneOffIncome(:final date) => month.contains(date),
      };

  static DateTime _nextMonthly(int dayOfMonth, DateTime day) {
    final thisMonth = YearMonth.of(day);
    final payday = monthlyPayday(dayOfMonth, thisMonth);
    return payday.isBefore(day)
        ? monthlyPayday(dayOfMonth, thisMonth.next)
        : payday;
  }

  static bool _before(DateTime date, IncomeSource source, NextIncome best) {
    if (date != best.date) return date.isBefore(best.date);
    final byName = source.name.compareTo(best.source.name);
    return byName != 0 ? byName < 0 : source.id.compareTo(best.source.id) < 0;
  }
}
