import '../../../../core/money/money_formatter.dart';
import '../../domain/value_objects/budget_alert.dart';

const _money = MoneyFormatter();

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The title and text of a budget alert's notification. Notifications can
/// be shown from the background, with no widget context for localized
/// dates, so dates are written here as "Oct 21".
abstract final class AlertMessages {
  static (String title, String body) of(BudgetAlert alert) => switch (alert) {
    CategoryLimitAlert(
      :final categoryName,
      :final usedPercent,
      :final spent,
      :final limit,
    ) =>
      usedPercent > 100
          ? (
              '$categoryName is over its limit',
              '${_money.format(spent)} of ${_money.format(limit)} this month.',
            )
          : (
              '$categoryName: $usedPercent% of its limit used',
              '${_money.format(spent)} of ${_money.format(limit)} this month, '
                  '${_money.format(limit - spent)} left.',
            ),
    RunOutAlert(:final runOut, :final next) => (
      next == null
          ? 'Your money may run out by ${day(runOut)}'
          : 'Your money may run out before ${next.source.name}',
      next == null
          ? 'At this pace it runs out around ${day(runOut)}, and no income '
                'is scheduled.'
          : 'At this pace it runs out around ${day(runOut)}; '
                '${next.source.name} comes on ${day(next.date)}.',
    ),
    UnusualSpendingAlert(:final categoryName, :final amount, :final median) => (
      'Unusual $categoryName expense: ${_money.format(amount)}',
      'About ${_times(amount.minorUnits, median.minorUnits)}× your usual '
          '${_money.format(median)} for $categoryName.',
    ),
  };

  /// A calendar day as "Oct 21".
  static String day(DateTime date) => '${_months[date.month - 1]} ${date.day}';

  /// [amount] ÷ [median] to a whole number, rounded half up.
  static int _times(int amount, int median) =>
      (amount * 2 + median) ~/ (median * 2);
}
