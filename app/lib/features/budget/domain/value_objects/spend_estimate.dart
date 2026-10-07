import 'package:freezed_annotation/freezed_annotation.dart';

import 'spend_rate.dart';

part 'spend_estimate.freezed.dart';

/// Daily spending learned from recent history: the expected rate and a
/// slower and a faster one for the forecast's range. Computed, never stored.
@freezed
abstract class SpendEstimate with _$SpendEstimate {
  const factory SpendEstimate({
    required SpendRate expected,

    /// Never above [expected] on either kind of day.
    required SpendRate low,

    /// Never below [expected] on either kind of day.
    required SpendRate high,

    /// Whole days from the first spending to today; 0 without any.
    required int daysOfData,
  }) = _SpendEstimate;
}
