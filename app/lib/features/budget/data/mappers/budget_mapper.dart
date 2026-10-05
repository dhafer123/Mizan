import '../../../../app/db/app_database.dart';
import '../../../../core/clock/year_month.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../expenses/data/mappers/expense_mapper.dart';
import '../../domain/entities/budget.dart';

/// Converts between budget rows and [Budget]. The month is stored as
/// `YYYY-MM`.
abstract final class BudgetMapper {
  static final _month = RegExp(r'^(\d{4})-(\d{2})$');

  /// Throws [FormatException] for a row this app version cannot read.
  static Budget toDomain(BudgetRow row) {
    final match = _month.firstMatch(row.month);
    final month = match == null ? null : int.parse(match.group(2)!);
    if (match == null || month! < 1 || month > 12) {
      throw FormatException('Unreadable budget month', row.month);
    }
    return Budget(
      id: row.id,
      month: YearMonth(int.parse(match.group(1)!), month),
      totalLimit: row.totalLimitMinor == null
          ? null
          : Money(
              row.totalLimitMinor!,
              ExpenseMapper.currencyFromCode(row.currency),
            ),
    );
  }

  /// A row for [budget], version 0. The row always names a currency: the
  /// limit's, or [currency] when there is no limit.
  static BudgetRow toRow(Budget budget, {required Currency currency}) =>
      BudgetRow(
        id: budget.id,
        month:
            '${budget.month.year.toString().padLeft(4, '0')}-'
            '${budget.month.month.toString().padLeft(2, '0')}',
        totalLimitMinor: budget.totalLimit?.minorUnits,
        currency: (budget.totalLimit?.currency ?? currency).code,
        version: 0,
        deleted: false,
      );
}
