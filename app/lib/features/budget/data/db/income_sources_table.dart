import 'package:drift/drift.dart';

import '../../../sync/data/db/sync_columns.dart';

/// Where money comes from: monthly on a day, one-off on a date, or irregular.
@DataClassName('IncomeSourceRow')
class IncomeSources extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();

  /// `monthly`, `oneOff` or `irregular`.
  TextColumn get scheduleType => text()();

  /// For `monthly`: day of the month it arrives (1-31).
  IntColumn get dayOfMonth => integer().nullable()();

  /// For `oneOff`: the date it arrives.
  DateTimeColumn get date => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31)',
  ];
}
