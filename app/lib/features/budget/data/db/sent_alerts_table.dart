import 'package:drift/drift.dart';

import '../../domain/value_objects/alert_type.dart';

/// Budget alerts this phone has sent. Local only: no sync columns and no
/// outbox, because notifications are per device (ADR 0013).
@DataClassName('SentAlertRow')
class SentAlerts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<AlertType>()();
  TextColumn get situation => text()();

  /// The calendar day it was sent (UTC midnight).
  DateTimeColumn get sentOn => dateTime()();

  /// For a run-out alert, the date it warned about.
  DateTimeColumn get runOut => dateTime().nullable()();
}
