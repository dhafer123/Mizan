import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';

part 'recurring_cost.freezed.dart';

/// A cost that comes back every month on the same day: rent, a phone plan.
/// The forecast subtracts it on its day instead of averaging it into daily
/// spending.
@freezed
abstract class RecurringCost with _$RecurringCost {
  const factory RecurringCost({
    required String name,
    required Money amount,

    /// 1-31. In shorter months it is due on the last day instead.
    required int dayOfMonth,

    /// When set, spending in this category is this cost being paid: it is
    /// left out of the daily spending average so it isn't counted twice.
    String? categoryId,
  }) = _RecurringCost;
}
