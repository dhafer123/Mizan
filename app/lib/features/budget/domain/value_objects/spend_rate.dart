import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';

part 'spend_rate.freezed.dart';

/// How much is spent per day, on a weekday and on a weekend day (Saturday
/// and Sunday): students spend differently on weekends.
@freezed
abstract class SpendRate with _$SpendRate {
  const factory SpendRate({required Money weekday, required Money weekend}) =
      _SpendRate;

  const SpendRate._();

  /// The same amount every day.
  factory SpendRate.flat(Money perDay) =>
      SpendRate(weekday: perDay, weekend: perDay);

  /// The spending expected on the calendar [day].
  Money on(DateTime day) => isWeekend(day) ? weekend : weekday;

  static bool isWeekend(DateTime day) =>
      day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
}
