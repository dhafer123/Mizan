import '../../../../app/db/app_database.dart';
import '../../../../core/money/money.dart';
import '../../../expenses/data/mappers/expense_mapper.dart';
import '../../domain/entities/income_source.dart';
import '../../domain/value_objects/income_schedule.dart';

/// Converts between income source rows and [IncomeSource]. The schedule is
/// stored as a type name (`monthly`, `oneOff`, `irregular`; never rename
/// them) plus the day or date it needs.
abstract final class IncomeSourceMapper {
  /// Throws [FormatException] for a row this app version cannot read.
  static IncomeSource toDomain(IncomeSourceRow row) => IncomeSource(
    id: row.id,
    name: row.name,
    amount: Money(
      row.amountMinor,
      ExpenseMapper.currencyFromCode(row.currency),
    ),
    schedule: switch (row.scheduleType) {
      'monthly' when row.dayOfMonth != null => IncomeSchedule.monthly(
        dayOfMonth: row.dayOfMonth!,
      ),
      'oneOff' when row.date != null => IncomeSchedule.oneOff(
        date: row.date!.toUtc(),
      ),
      'irregular' => const IncomeSchedule.irregular(),
      _ => throw FormatException('Unreadable income schedule', row.id),
    },
  );

  /// A row for a new source: version 0. When updating, the DAO keeps the
  /// stored sync metadata instead.
  static IncomeSourceRow toRow(IncomeSource source) {
    final (type, day, date) = switch (source.schedule) {
      MonthlyIncome(:final dayOfMonth) => ('monthly', dayOfMonth, null),
      OneOffIncome(:final date) => ('oneOff', null, date.toUtc()),
      IrregularIncome() => ('irregular', null, null),
    };
    return IncomeSourceRow(
      id: source.id,
      name: source.name,
      amountMinor: source.amount.minorUnits,
      currency: source.amount.currency.code,
      scheduleType: type,
      dayOfMonth: day,
      date: date,
      version: 0,
      deleted: false,
    );
  }
}
