import 'dart:math' as math;

import '../../../../core/clock/calendar_day.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../groups/domain/value_objects/group_share.dart';
import '../value_objects/spend_estimate.dart';
import '../value_objects/spend_rate.dart';

/// Learns daily spending from the last [windowDays] days before today
/// (today is still going): personal expenses plus my shares of group
/// expenses.
///
/// - **Expected rate:** an exponentially weighted average of each day's
///   total (half-life [halfLifeDays] days, so last week counts most), apart
///   for weekdays and weekend days. Days with no spending count as 0.
/// - **Range:** the 25th and 75th percentile of the 7-day totals in the
///   window, as a share of their mean, scale the expected rate down and up.
///   Single days are too lumpy for percentiles (most are 0 for a student
///   who shops twice a week); weeks aren't. See ADR 0012.
///
/// The window never reaches before the first spending, so a new user's
/// empty days don't pull the average down. Integer arithmetic only: the
/// rates are exact minor units, rounded half up.
class EstimateDailySpend {
  const EstimateDailySpend();

  static const windowDays = 28;
  static const halfLifeDays = 7;

  /// Weight of the day [age] days before today, at index `age - 1`, in
  /// fixed point (2^20 for yesterday).
  static final List<int> _weights = List.unmodifiable([
    for (var age = 1; age <= windowDays; age++)
      ((1 << 20) * math.pow(0.5, (age - 1) / halfLifeDays)).round(),
  ]);

  SpendEstimate call({
    required DateTime today,
    required Currency currency,
    required List<Expense> expenses,
    List<GroupShare> shares = const [],

    /// Paid as recurring costs, which the forecast subtracts on their own
    /// day: left out of the rates (but they still count as history).
    Set<String> excludedCategoryIds = const {},
  }) {
    final day0 = today.calendarDay;
    final spending = <(DateTime, String?, Money)>[
      for (final e in expenses) (e.date, e.categoryId, e.amount),
      for (final s in shares) (s.date, s.categoryId, s.amount),
    ].where((s) => s.$1.isBefore(day0)).toList();

    final first = spending.isEmpty
        ? null
        : spending.map((s) => s.$1).reduce((a, b) => a.isBefore(b) ? a : b);
    if (first == null) {
      final none = SpendRate.flat(Money.zero(currency));
      return SpendEstimate(
        expected: none,
        low: none,
        high: none,
        daysOfData: 0,
      );
    }

    final daysOfData = day0.difference(first).inDays;
    final length = math.min(daysOfData, windowDays);
    final start = day0.subtract(Duration(days: length));
    // totals[i] is the spending on start + i days.
    final totals = List<int>.filled(length, 0);
    for (final (date, categoryId, amount) in spending) {
      if (date.isBefore(start)) continue;
      if (excludedCategoryIds.contains(categoryId)) continue;
      totals[date.difference(start).inDays] += amount.minorUnits;
    }

    final expected = SpendRate(
      weekday: Money(_weightedMean(totals, start, weekend: false), currency),
      weekend: Money(_weightedMean(totals, start, weekend: true), currency),
    );

    final weeks = [
      for (var end = 6; end < length; end++)
        totals.sublist(end - 6, end + 1).fold(0, (a, b) => a + b),
    ];
    final weeksTotal = weeks.fold(0, (a, b) => a + b);
    if (weeksTotal == 0) {
      return SpendEstimate(
        expected: expected,
        low: expected,
        high: expected,
        daysOfData: daysOfData,
      );
    }
    final sorted = [...weeks]..sort();
    // Rate × percentile ÷ mean, with mean = weeksTotal ÷ weeks.length.
    SpendRate scaled(int percentile, {required bool up}) {
      Money scale(Money rate) {
        final value = _divideRounded(
          BigInt.from(rate.minorUnits) *
              BigInt.from(_percentile(sorted, percentile)) *
              BigInt.from(weeks.length),
          BigInt.from(weeksTotal),
        );
        final m = Money(value, currency);
        return up ? (m > rate ? m : rate) : (m < rate ? m : rate);
      }

      return SpendRate(
        weekday: scale(expected.weekday),
        weekend: scale(expected.weekend),
      );
    }

    return SpendEstimate(
      expected: expected,
      low: scaled(25, up: false),
      high: scaled(75, up: true),
      daysOfData: daysOfData,
    );
  }

  /// The weighted average of the weekday (or weekend) days in [totals].
  /// 0 if there are none.
  static int _weightedMean(
    List<int> totals,
    DateTime start, {
    required bool weekend,
  }) {
    var sum = BigInt.zero;
    var weights = 0;
    for (var i = 0; i < totals.length; i++) {
      final day = start.add(Duration(days: i));
      if (SpendRate.isWeekend(day) != weekend) continue;
      final weight = _weights[totals.length - i - 1];
      sum += BigInt.from(totals[i]) * BigInt.from(weight);
      weights += weight;
    }
    return weights == 0 ? 0 : _divideRounded(sum, BigInt.from(weights));
  }

  /// Nearest-rank percentile of the ascending, non-empty [sorted].
  static int _percentile(List<int> sorted, int percent) {
    final rank = (percent * sorted.length + 99) ~/ 100;
    return sorted[math.max(rank, 1) - 1];
  }

  /// [numerator] ÷ [denominator] rounded half up; both not negative.
  static int _divideRounded(BigInt numerator, BigInt denominator) =>
      ((numerator * BigInt.two + denominator) ~/ (denominator * BigInt.two))
          .toInt();
}
