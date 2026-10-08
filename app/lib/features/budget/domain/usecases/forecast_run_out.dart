import '../../../../core/clock/calendar_day.dart';
import '../../../../core/clock/year_month.dart';
import '../../../../core/money/money.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../groups/domain/value_objects/group_share.dart';
import '../entities/income_source.dart';
import '../value_objects/income_schedule.dart';
import '../value_objects/recurring_cost.dart';
import '../value_objects/run_out_forecast.dart';
import '../value_objects/spend_rate.dart';
import 'compute_money_available.dart';
import 'estimate_daily_spend.dart';

/// When does money left hit 0? (ARCHITECTURE.md §7, ADR 0012.)
///
/// Starts from today's money left (this month's income − spending, as on
/// Home), plus what's owed to me when given. Then steps one day at a time
/// from tomorrow to [horizonDays] days out. Each day:
/// 1. adds the income paid that day in a *later* month (this month's is
///    already in money left): monthly on its payday, one-offs on their
///    date, irregular sources on the 1st;
/// 2. subtracts the recurring costs due that day;
/// 3. subtracts the expected spending for a weekday or weekend day.
///
/// The run-out date is the first day the balance goes below 0 (today if it
/// already is). The range repeats this with the faster and slower rates.
///
/// Cold start (fewer than [coldStartDays] days of history): the rate is the
/// monthly budget spread over this month's days, and there is no range.
/// Without a budget there is no forecast.
class ForecastRunOut {
  const ForecastRunOut({
    EstimateDailySpend estimate = const EstimateDailySpend(),
  }) : _estimate = estimate;

  final EstimateDailySpend _estimate;

  static const horizonDays = 60;
  static const coldStartDays = 14;

  RunOutForecast call({
    required DateTime today,

    /// Money left this month (see `MoneyAvailable.available`).
    required Money available,
    required List<IncomeSource> incomes,

    /// At least the [EstimateDailySpend.windowDays] days before today.
    required List<Expense> expenses,

    /// My shares of group expenses.
    List<GroupShare> shares = const [],
    List<RecurringCost> recurring = const [],

    /// Added to the start when given: the "include money owed to me" option.
    Money? owedToMe,

    /// This month's overall budget, for cold start.
    Money? monthlyBudget,
  }) {
    final day0 = today.calendarDay;
    final currency = available.currency;
    final estimate = _estimate(
      today: day0,
      currency: currency,
      expenses: expenses,
      shares: shares,
      excludedCategoryIds: {for (final cost in recurring) ?cost.categoryId},
    );

    final coldStart = estimate.daysOfData < coldStartDays;
    if (coldStart && monthlyBudget == null) {
      return RunOutForecast.needsData(daysOfData: estimate.daysOfData);
    }
    final (expected, low, high) = coldStart
        ? _budgetRates(monthlyBudget!, day0)
        : (estimate.expected, estimate.low, estimate.high);

    final start = owedToMe == null ? available : available + owedToMe;
    DateTime? project(SpendRate rate) =>
        _project(day0, start, rate, incomes, recurring);

    return RunOutForecast.projected(
      today: day0,
      horizonEnd: day0.add(const Duration(days: horizonDays)),
      start: start,
      runOut: project(expected),
      earliest: project(high),
      latest: project(low),
      rate: expected,
      coldStart: coldStart,
    );
  }

  /// The budget spread evenly over [day0]'s month, rounded half up; the
  /// same rate for all three.
  static (SpendRate, SpendRate, SpendRate) _budgetRates(
    Money budget,
    DateTime day0,
  ) {
    final month = YearMonth.of(day0);
    final days = month.endExclusive.difference(month.firstDay).inDays;
    final rate = SpendRate.flat(
      Money((budget.minorUnits * 2 + days) ~/ (days * 2), budget.currency),
    );
    return (rate, rate, rate);
  }

  static DateTime? _project(
    DateTime day0,
    Money start,
    SpendRate rate,
    List<IncomeSource> incomes,
    List<RecurringCost> recurring,
  ) => runOutDay(
    today: day0,
    start: start,
    spendOn: rate.on,
    until: day0.add(const Duration(days: horizonDays)),
    incomes: incomes,
    recurring: recurring,
  );

  /// The first day after [today], up to [until], that [start] goes below 0
  /// when [spendOn] is spent each day, with later months' income and the
  /// [recurring] costs counted as in the forecast. [today] if [start]
  /// already is below 0; null if the money lasts to [until].
  ///
  /// The forecast spends its expected rate; the backtest (task 5.3) spends
  /// what was really spent, so both count money the same way.
  static DateTime? runOutDay({
    required DateTime today,
    required Money start,
    required Money Function(DateTime day) spendOn,
    required DateTime until,
    List<IncomeSource> incomes = const [],
    List<RecurringCost> recurring = const [],
  }) {
    final day0 = today.calendarDay;
    if (start.isNegative) return day0;
    final thisMonth = YearMonth.of(day0);
    var balance = start;
    for (
      var day = day0.add(const Duration(days: 1));
      !day.isAfter(until);
      day = day.add(const Duration(days: 1))
    ) {
      final month = YearMonth.of(day);
      if (month.compareTo(thisMonth) > 0) {
        for (final source in incomes) {
          if (_paysOn(source.schedule, day, month)) balance += source.amount;
        }
      }
      for (final cost in recurring) {
        if (ComputeMoneyAvailable.monthlyPayday(cost.dayOfMonth, month) ==
            day) {
          balance -= cost.amount;
        }
      }
      balance -= spendOn(day);
      if (balance.isNegative) return day;
    }
    return null;
  }

  static bool _paysOn(IncomeSchedule schedule, DateTime day, YearMonth month) =>
      switch (schedule) {
        MonthlyIncome(:final dayOfMonth) =>
          ComputeMoneyAvailable.monthlyPayday(dayOfMonth, month) == day,
        OneOffIncome(:final date) => date == day,
        IrregularIncome() => day.day == 1,
      };
}
