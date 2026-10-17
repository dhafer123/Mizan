import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/value_objects/run_out_forecast.dart';
import 'package:mizan/features/budget/domain/value_objects/spend_rate.dart';
import 'package:mizan/features/budget/presentation/home/runway.dart';

DateTime _oct(int day) => DateTime.utc(2026, 10, day);

ProjectedForecast _forecast({
  DateTime? runOut,
  DateTime? earliest,
  DateTime? latest,
}) =>
    RunOutForecast.projected(
          today: _oct(5),
          horizonEnd: _oct(5).add(const Duration(days: 60)),
          start: const Money(100000, Currency.tnd),
          runOut: runOut,
          earliest: earliest,
          latest: latest,
          rate: SpendRate.flat(const Money(5000, Currency.tnd)),
          coldStart: false,
        )
        as ProjectedForecast;

void main() {
  test('ends at the next income, with the run-out where it falls', () {
    // Today Oct 5, payday Oct 15: 10 days. Runs out on the 10th (±2 days).
    final runway = Runway.of(
      _forecast(runOut: _oct(10), earliest: _oct(8), latest: _oct(12)),
      nextIncome: _oct(15),
    );

    expect(runway.end, _oct(15));
    expect(runway.endsAtIncome, isTrue);
    expect(runway.runOut, 0.5);
    expect(runway.riskStart, closeTo(0.3, 1e-9));
    expect(runway.riskEnd, closeTo(0.7, 1e-9));
    expect(runway.isSafe, isFalse);
  });

  test('money that lasts past payday is safe', () {
    final runway = Runway.of(
      _forecast(runOut: _oct(25), earliest: _oct(20), latest: _oct(30)),
      nextIncome: _oct(15),
    );

    expect(runway.runOut, isNull);
    expect(runway.riskStart, isNull);
    expect(runway.isSafe, isTrue);
  });

  test('safe at the expected rate, at risk at the faster one', () {
    final runway = Runway.of(
      _forecast(runOut: _oct(18), earliest: _oct(13), latest: _oct(22)),
      nextIncome: _oct(15),
    );

    expect(runway.runOut, isNull);
    expect(runway.riskStart, 0.8);
    expect(runway.riskEnd, 1, reason: 'the range runs past payday');
    expect(runway.isSafe, isFalse);
  });

  test('without an income ahead it ends at the horizon', () {
    for (final income in [null, _oct(5), _oct(1)]) {
      final runway = Runway.of(_forecast(), nextIncome: income);
      expect(runway.end, _oct(5).add(const Duration(days: 60)));
      expect(runway.endsAtIncome, isFalse);
      expect(runway.isSafe, isTrue);
    }
  });

  test('money already gone today sits at the start', () {
    final runway = Runway.of(
      _forecast(runOut: _oct(5), earliest: _oct(5), latest: _oct(5)),
      nextIncome: _oct(15),
    );

    expect(runway.runOut, 0);
    expect(runway.riskStart, 0);
    expect(runway.riskEnd, 0);
  });
}
