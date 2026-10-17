import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';

part 'penny_reason.freezed.dart';

/// Why Penny looks the way she does, with the facts she must say. Her joke
/// can change; these facts are always in her line, so the joke never hides
/// the information.
@freezed
sealed class PennyReason with _$PennyReason {
  /// At the expected rate the money runs out on [runOut], before [payday]
  /// (or with no income scheduled at all). [alreadyOut] when that's today:
  /// this month's money is gone.
  const factory PennyReason.runningOut({
    required DateTime runOut,
    DateTime? payday,
    @Default(false) bool alreadyOut,
  }) = RunningOut;

  /// [category] has spent more than its monthly limit, by [over].
  const factory PennyReason.overLimit({
    required String category,
    required Money over,
  }) = OverLimit;

  /// [category] has used [percent]% (80 to 99) of its monthly limit.
  const factory PennyReason.nearLimit({
    required String category,
    required int percent,
  }) = NearLimit;

  /// An expense of [amount] in [category], far above its usual.
  const factory PennyReason.bigExpense({
    required String category,
    required Money amount,
  }) = BigExpense;

  /// No internet: changes are kept on the phone until it's back.
  const factory PennyReason.offline() = Offline;

  /// No income set up, so nothing to forecast against.
  const factory PennyReason.needsIncome() = NeedsIncome;

  /// Nothing spent yet this month.
  const factory PennyReason.quietMonth() = QuietMonth;

  /// Too little history for a forecast: [daysToGo] more days of logging.
  const factory PennyReason.learning({required int daysToGo}) = Learning;

  /// The money lasts until at least [until]: the next income when
  /// [untilPayday], else the end of the forecast.
  const factory PennyReason.onTrack({
    required DateTime until,
    required bool untilPayday,
  }) = OnTrack;
}
