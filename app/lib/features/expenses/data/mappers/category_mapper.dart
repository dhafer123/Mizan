import '../../../../app/db/app_database.dart';
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
}
