import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/budget/data/repositories/alert_log_impl.dart';
import 'package:mizan/features/budget/domain/value_objects/alert_type.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';
import 'package:mizan/features/budget/domain/value_objects/sent_alert.dart';

import '../../../../support/test_database.dart';

DateTime _day(int month, int day) => DateTime.utc(2026, month, day);

List<SentAlert> _value(Result<List<SentAlert>, BudgetFailure> result) =>
    (result as Ok<List<SentAlert>, BudgetFailure>).value;

void main() {
  late AppDatabase db;
  late AlertLogImpl log;

  setUp(() {
    db = openTestDatabase();
    log = AlertLogImpl(db.sentAlertsDao);
  });
  tearDown(() => db.close());

  test('records alerts and reads back those sent since a day', () async {
    final runOut = SentAlert(
      type: AlertType.runOut,
      situation: '2026-10-25T00:00:00.000Z',
      sentOn: _day(10, 18),
      runOut: _day(10, 22),
    );
    final category = SentAlert(
      type: AlertType.categoryLimit,
      situation: 'food@2026-10',
      sentOn: _day(10, 5),
    );
    expect(await log.record(runOut), isA<Ok<void, BudgetFailure>>());
    await log.record(category);

    expect(_value(await log.sentSince(_day(10, 1))), [runOut, category]);
    expect(_value(await log.sentSince(_day(10, 18))), [runOut]);
    expect(_value(await log.sentSince(_day(10, 19))), isEmpty);
  });

  test('forgets alerts long past what is read back', () async {
    final old = SentAlert(
      type: AlertType.unusualSpending,
      situation: 'e1',
      sentOn: _day(6, 1),
    );
    final recent = old.copyWith(situation: 'e2', sentOn: _day(9, 1));
    await log.record(old);
    await log.record(recent);
    await log.record(old.copyWith(situation: 'e3', sentOn: _day(10, 20)));

    final kept = _value(await log.sentSince(DateTime.utc(2000)));
    expect(kept.map((s) => s.situation), ['e2', 'e3']);
  });

  test('a database failure is returned, not thrown', () async {
    await db.customStatement('DROP TABLE sent_alerts');
    expect(
      await log.sentSince(_day(10, 1)),
      isA<Err<List<SentAlert>, BudgetFailure>>(),
    );
    expect(
      await log.record(
        SentAlert(type: AlertType.runOut, situation: 'x', sentOn: _day(10, 1)),
      ),
      isA<Err<void, BudgetFailure>>(),
    );
  });
}
