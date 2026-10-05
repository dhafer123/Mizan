import 'package:freezed_annotation/freezed_annotation.dart';

part 'year_month.freezed.dart';

/// A calendar month, e.g. October 2026. Budgets and expense lists are per
/// month.
@freezed
abstract class YearMonth with _$YearMonth implements Comparable<YearMonth> {
  @Assert('month >= 1 && month <= 12', 'month must be 1-12')
  const factory YearMonth(int year, int month) = _YearMonth;

  const YearMonth._();

  /// The month [date] falls in, read in its own time zone.
  factory YearMonth.of(DateTime date) => YearMonth(date.year, date.month);

  /// The first calendar day of the month (UTC midnight, see `CalendarDay`).
  DateTime get firstDay => DateTime.utc(year, month);

  /// The first calendar day of the next month: the exclusive end of this one.
  DateTime get endExclusive => DateTime.utc(year, month + 1);

  YearMonth get next => YearMonth.of(endExclusive);

  YearMonth get previous => YearMonth.of(DateTime.utc(year, month - 1));

  /// Whether the calendar [day] is in this month.
  bool contains(DateTime day) =>
      !day.isBefore(firstDay) && day.isBefore(endExclusive);

  @override
  int compareTo(YearMonth other) =>
      year != other.year ? year - other.year : month - other.month;
}
