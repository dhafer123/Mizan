import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';
import 'next_income.dart';

part 'money_available.freezed.dart';

/// A month's income against its spending. Computed, never stored.
@freezed
abstract class MoneyAvailable with _$MoneyAvailable {
  const factory MoneyAvailable({
    /// Expected for the month: every monthly and irregular source, plus
    /// one-offs dated in the month.
    required Money income,
    required Money spent,

    /// The next income on or after today, if any is scheduled.
    NextIncome? next,
  }) = _MoneyAvailable;

  const MoneyAvailable._();

  /// Income minus spending; negative when spending is ahead of income. No
  /// carry-over from earlier months.
  Money get available => income - spent;
}
