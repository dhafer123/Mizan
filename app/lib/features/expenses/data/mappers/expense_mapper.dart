import '../../../../app/db/app_database.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/expense.dart';
import '../../domain/value_objects/expense_source.dart';

/// Converts between expense rows and [Expense].
abstract final class ExpenseMapper {
  /// Throws [FormatException] for a row this app version cannot read.
  static Expense toDomain(ExpenseRow row) => Expense(
    id: row.id,
    amount: Money(row.amountMinor, currencyFromCode(row.currency)),
    categoryId: row.categoryId,
    date: row.date.toUtc(),
    note: row.note,
    source:
        ExpenseSource.values.asNameMap()[row.source] ??
        (throw FormatException('Unknown expense source', row.source)),
  );

  /// A row for a new expense: version 0, not yet seen by the server. When
  /// updating, the DAO keeps the stored sync metadata instead.
  static ExpenseRow toRow(Expense expense) => ExpenseRow(
    id: expense.id,
    amountMinor: expense.amount.minorUnits,
    currency: expense.amount.currency.code,
    categoryId: expense.categoryId,
    date: expense.date.toUtc(),
    note: expense.note,
    source: expense.source.name,
    version: 0,
    deleted: false,
  );

  static Currency currencyFromCode(String code) =>
      Currency.fromCode(code) ??
      (throw FormatException('Unknown currency', code));
}
