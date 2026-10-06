import '../../../../app/db/app_database.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../expenses/data/mappers/expense_mapper.dart';
import '../../domain/entities/shared_expense.dart';
import '../../domain/value_objects/split.dart';

/// Shared expense rows ↔ entities. The split's JSON is the server's
/// (`expected_shares` in server/sync/entities.py):
/// `{"type": "equal", "memberIds": [...]}`, `{"type": "exact", "amounts":
/// {id: minor}}`, `{"type": "percentage", "basisPoints": {id: bp}}` or
/// `{"type": "shares", "weights": {id: w}}`.
abstract final class SharedExpenseMapper {
  /// Throws [FormatException] for a row this app version can't read.
  static SharedExpense toDomain(SharedExpenseRow row) {
    final currency = ExpenseMapper.currencyFromCode(row.currency);
    return SharedExpense(
      id: row.id,
      groupId: row.groupId,
      payerId: row.payerId,
      amount: Money(row.amountMinor, currency),
      date: row.date.toUtc(),
      split: splitFromJson(row.split, currency),
      shares: {
        for (final MapEntry(:key, :value) in _ints(row.shares).entries)
          key: Money(value, currency),
      },
      categoryId: row.categoryId,
    );
  }

  /// A new row (version 0).
  static SharedExpenseRow toRow(SharedExpense expense) => SharedExpenseRow(
    id: expense.id,
    groupId: expense.groupId,
    payerId: expense.payerId,
    amountMinor: expense.amount.minorUnits,
    currency: expense.amount.currency.code,
    date: expense.date,
    split: splitToJson(expense.split),
    shares: {
      for (final MapEntry(:key, :value) in expense.shares.entries)
        key: value.minorUnits,
    },
    categoryId: expense.categoryId,
    version: 0,
    deleted: false,
  );

  static Map<String, Object?> splitToJson(Split split) => switch (split) {
    EqualSplit(:final memberIds) => {
      'type': 'equal',
      'memberIds': memberIds.toList()..sort(),
    },
    ExactSplit(:final amounts) => {
      'type': 'exact',
      'amounts': {
        for (final MapEntry(:key, :value) in amounts.entries)
          key: value.minorUnits,
      },
    },
    PercentageSplit(:final basisPoints) => {
      'type': 'percentage',
      'basisPoints': basisPoints,
    },
    SharesSplit(:final weights) => {'type': 'shares', 'weights': weights},
  };

  static Split splitFromJson(Map<String, Object?> json, Currency currency) =>
      switch (json) {
        {'type': 'equal', 'memberIds': final List<Object?> ids} => Split.equal(
          ids.cast<String>().toSet(),
        ),
        {'type': 'exact', 'amounts': final Map<Object?, Object?> amounts} =>
          Split.exact({
            for (final MapEntry(:key, :value) in _ints(amounts).entries)
              key: Money(value, currency),
          }),
        {'type': 'percentage', 'basisPoints': final Map<Object?, Object?> bp} =>
          Split.percentage(_ints(bp)),
        {'type': 'shares', 'weights': final Map<Object?, Object?> weights} =>
          Split.shares(_ints(weights)),
        _ => throw FormatException('Unknown split', json),
      };

  static Map<String, int> _ints(Map<Object?, Object?> json) => {
    for (final MapEntry(:key, :value) in json.entries)
      key! as String: value! as int,
  };
}
