import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';
import '../value_objects/income_schedule.dart';

part 'income_source.freezed.dart';

/// Where money comes from: a grant, a job, family support.
@freezed
abstract class IncomeSource with _$IncomeSource {
  const factory IncomeSource({
    required String id,
    required String name,

    /// Per payment; for irregular income, the typical amount per month.
    required Money amount,
    required IncomeSchedule schedule,
  }) = _IncomeSource;
}
