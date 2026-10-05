import '../../../../app/db/app_database.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/category.dart';
import 'expense_mapper.dart';

abstract final class CategoryMapper {
  /// Throws [FormatException] for a row this app version cannot read.
  static Category toDomain(CategoryRow row) => Category(
    id: row.id,
    name: row.name,
    icon: row.icon,
    monthlyLimit: row.monthlyLimitMinor == null
        ? null
        : Money(
            row.monthlyLimitMinor!,
            ExpenseMapper.currencyFromCode(row.currency),
          ),
    archived: row.archived,
  );

  /// A row for [category], version 0. The row always names a currency: the
  /// limit's, or [currency] when there is no limit.
  static CategoryRow toRow(Category category, {required Currency currency}) =>
      CategoryRow(
        id: category.id,
        name: category.name,
        icon: category.icon,
        monthlyLimitMinor: category.monthlyLimit?.minorUnits,
        currency: (category.monthlyLimit?.currency ?? currency).code,
        archived: category.archived,
        version: 0,
        deleted: false,
      );
}
