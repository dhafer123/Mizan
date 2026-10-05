import 'package:freezed_annotation/freezed_annotation.dart';

part 'income_schedule.freezed.dart';

/// When an income source pays.
@freezed
sealed class IncomeSchedule with _$IncomeSchedule {
  const IncomeSchedule._();

  /// Every month on [dayOfMonth] (1-31). In shorter months it arrives on the
  /// last day instead.
  const factory IncomeSchedule.monthly({required int dayOfMonth}) =
      MonthlyIncome;

  /// Once, on the calendar day [date].
  const factory IncomeSchedule.oneOff({required DateTime date}) = OneOffIncome;

  /// No fixed date. Its amount is what typically comes in per month, and it
  /// counts towards every month.
  const factory IncomeSchedule.irregular() = IrregularIncome;
}
