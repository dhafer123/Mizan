import 'package:freezed_annotation/freezed_annotation.dart';

import '../entities/income_source.dart';

part 'next_income.freezed.dart';

/// When [source] pays next.
@freezed
abstract class NextIncome with _$NextIncome {
  const factory NextIncome({
    required IncomeSource source,

    /// A calendar day (UTC midnight).
    required DateTime date,
  }) = _NextIncome;
}
