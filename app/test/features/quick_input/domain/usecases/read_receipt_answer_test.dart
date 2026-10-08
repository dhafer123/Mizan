import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/quick_input/domain/usecases/read_receipt_answer.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_error.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';
import 'package:mizan/features/quick_input/domain/value_objects/receipt_reading.dart';

const _rows = ['Kiosque', 'Chips 1,200', 'Somme due 2,000', 'Recu 5,000'];
final _today = DateTime.utc(2026, 10, 8);

Result<ReceiptReading, QuickInputFailure> _read(String answer) =>
    const ReadReceiptAnswer()(
      answer,
      rows: _rows,
      currency: Currency.tnd,
      today: _today,
    );

void main() {
  test('a printed total and a sane date are kept', () {
    final reading = _read(
      'Here: {"total":"2.000","date":"2026-10-07"}',
    ).valueOrNull!;
    expect(reading.total, const Money(2000, Currency.tnd));
    expect(reading.date, DateTime.utc(2026, 10, 7));
    expect(reading.confidence, ReadReceiptAnswer.confidence);
  });

  test('a number total works; a bad or missing date is dropped', () {
    expect(_read('{"total":2,"date":"07/10/2026"}').valueOrNull?.date, isNull);
    expect(
      _read('{"total":2.0,"date":null}').valueOrNull?.total,
      const Money(2000, Currency.tnd),
    );
    expect(
      _read('{"total":"2,000","date":"2026-10-09"}').valueOrNull?.date,
      isNull,
    ); // Tomorrow.
  });

  group('rejects', () {
    const invalid = Err<ReceiptReading, QuickInputFailure>(
      QuickInputFailure(QuickInputError.llmInvalid),
    );
    final cases = {
      'no JSON': 'The total is 2 dinars.',
      'broken JSON': '{"total":"2.000"',
      'no total': '{"date":"2026-10-07"}',
      'a null total': '{"total":null}',
      'a total in words': '{"total":"two"}',
      'a zero total': '{"total":"0"}',
      'a total not on the receipt': '{"total":"3.500"}',
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      test(key, () => expect(_read(value), invalid));
    }
  });
}
