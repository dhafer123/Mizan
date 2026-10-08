import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import 'sent_alerts_table.dart';

part 'sent_alerts_dao.g.dart';

@DriftAccessor(tables: [SentAlerts])
class SentAlertsDao extends DatabaseAccessor<AppDatabase>
    with _$SentAlertsDaoMixin {
  SentAlertsDao(super.attachedDatabase);

  /// The rows sent on or after the calendar [day]. Filtered here rather than
  /// in SQL: dates are stored as ISO text, and the table holds a few rows a
  /// day at most.
  Future<List<SentAlertRow>> sentSince(DateTime day) async => [
    for (final row in await select(sentAlerts).get())
      if (!row.sentOn.isBefore(day)) row,
  ];

  /// Logs one alert, and forgets those older than [keep] days before it:
  /// nothing reads that far back.
  Future<void> record(SentAlertsCompanion row, {required Duration keep}) =>
      transaction(() async {
        await into(sentAlerts).insert(row);
        final cutoff = row.sentOn.value.subtract(keep);
        final old = [
          for (final r in await select(sentAlerts).get())
            if (r.sentOn.isBefore(cutoff)) r.id,
        ];
        if (old.isNotEmpty) {
          await (delete(sentAlerts)..where((r) => r.id.isIn(old))).go();
        }
      });
}
