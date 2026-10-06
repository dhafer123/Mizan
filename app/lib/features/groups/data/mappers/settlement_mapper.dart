import '../../../../app/db/app_database.dart';
import '../../../../core/money/money.dart';
import '../../../expenses/data/mappers/expense_mapper.dart';
import '../../domain/entities/settlement.dart';

abstract final class SettlementMapper {
  /// Throws [FormatException] for a currency this app version can't read.
  static Settlement toDomain(SettlementRow row) => Settlement(
    id: row.id,
    groupId: row.groupId,
    fromMemberId: row.fromMemberId,
    toMemberId: row.toMemberId,
    amount: Money(
      row.amountMinor,
      ExpenseMapper.currencyFromCode(row.currency),
    ),
    date: row.date.toUtc(),
    reversesId: row.reversesId,
  );

  /// A new row (version 0).
  static SettlementRow toRow(Settlement s) => SettlementRow(
    id: s.id,
    groupId: s.groupId,
    fromMemberId: s.fromMemberId,
    toMemberId: s.toMemberId,
    amountMinor: s.amount.minorUnits,
    currency: s.amount.currency.code,
    date: s.date,
    reversesId: s.reversesId,
    version: 0,
    deleted: false,
  );
}
