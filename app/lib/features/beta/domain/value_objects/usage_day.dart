import 'package:freezed_annotation/freezed_annotation.dart';

part 'usage_day.freezed.dart';

/// How many expenses were logged on one day, by input method. Counts only:
/// no amounts, notes or categories.
@freezed
abstract class UsageDay with _$UsageDay {
  const factory UsageDay({
    /// A calendar day (UTC midnight, see `CalendarDay`).
    required DateTime day,
    @Default(0) int manual,
    @Default(0) int voice,
    @Default(0) int receipt,
  }) = _UsageDay;
}
