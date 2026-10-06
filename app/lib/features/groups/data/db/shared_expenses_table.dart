import 'package:drift/drift.dart';

import '../../../sync/data/db/sync_columns.dart';

/// JSON objects stored as text, and sent to the server as objects.
final jsonObjectConverter = TypeConverter.json2<Map<String, Object?>>(
  fromJson: (json) => (json! as Map).cast<String, Object?>(),
);

/// Expenses paid by one member for some of the group. [split] is the rule as
/// entered and [shares] what it gave (`{memberId: minor units}`), stored so
/// rounding changes can never move old balances. Same JSON as the server
/// (server/sync/entities.py).
@DataClassName('SharedExpenseRow')
@TableIndex(name: 'shared_expenses_group', columns: {#groupId})
class SharedExpenses extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get payerId => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  DateTimeColumn get date => dateTime()();
  TextColumn get split => text().map(jsonObjectConverter)();
  TextColumn get shares => text().map(jsonObjectConverter)();
  TextColumn get categoryId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
