import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/quick_input/domain/usecases/read_receipt.dart';
import 'package:mizan/features/quick_input/domain/usecases/scan_receipt.dart';
import 'package:mizan/features/quick_input/domain/value_objects/parse_method.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_error.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_parse.dart';

import '../../../../support/fake_expense_llm.dart';
import '../../../../support/fake_receipt_scanner.dart';

final _today = DateTime.utc(2026, 10, 8, 14);
const _named = ['Café Le Baron', '07/10/2026', 'TOTAL  3,000'];

/// No named total: the rules' guess, the largest amount, is the cash paid.
const _unnamed = ['Kiosque', 'Chips 1,200', 'Eau 0,800', 'Paye 5,000', '2,000'];

void main() {
  late FakeExpenseLlm llm;
  late ReadReceipt read;

  setUp(() {
    llm = FakeExpenseLlm(answer: const Ok('{"total":"2.000","date":null}'));
    read = ReadReceipt(llm, timeout: const Duration(milliseconds: 50));
  });

  Future<QuickParse> readRows(List<String> rows) => read(
    FakeReceiptScanner.linesOf(rows),
    currency: Currency.tnd,
    today: _today,
  );

  test('a named total: one item for the shop, with the date, no LLM', () async {
    final parse = await readRows(_named);
    expect(parse.method, ParseMethod.rules);
    expect(parse.text, 'Café Le Baron');
    expect(parse.date, DateTime.utc(2026, 10, 7));
    expect(parse.items.single.label, 'Café Le Baron');
    expect(parse.items.single.amount, const Money(3000, Currency.tnd));
    expect(llm.prompts, isEmpty);
  });

  test(
    'no named total: the LLM reads it, checked against the receipt',
    () async {
      // Rules alone would take the largest amount (5.000).
      final parse = await readRows(_unnamed);
      expect(parse.method, ParseMethod.llm);
      expect(parse.items.single.amount, const Money(2000, Currency.tnd));
      expect(llm.prompts.single, contains('Paye 5,000'));
    },
  );

  group('the rules stand when the LLM', () {
    Future<void> expectRules(QuickInputError error) async {
      final parse = await readRows(_unnamed);
      expect(parse.method, ParseMethod.rules);
      expect(parse.items.single.amount, const Money(5000, Currency.tnd));
      expect(parse.items.single.confidence, lessThan(60));
      expect(parse.llmFailure, QuickInputFailure(error));
    }

    test('is not downloaded', () async {
      llm.installed = false;
      await expectRules(QuickInputError.modelNotInstalled);
    });

    test('fails or hangs', () async {
      llm.answer = null;
      await expectRules(QuickInputError.llmFailed);
    });

    test('invents a total', () async {
      llm.answer = const Ok('{"total":"9.999"}');
      await expectRules(QuickInputError.llmInvalid);
    });
  });

  test('a blank photo: no items, no LLM', () async {
    final parse = await readRows(const []);
    expect(parse.items, isEmpty);
    expect(parse.text, 'Receipt');
    expect(llm.prompts, isEmpty);
  });

  group('ScanReceipt', () {
    test('reads the photo, then the receipt', () async {
      final scanner = FakeReceiptScanner(_named);
      final result = await ScanReceipt(scanner, read)(
        '/x.jpg',
        currency: Currency.tnd,
        today: _today,
      );
      expect(
        result.valueOrNull?.items.single.amount,
        const Money(3000, Currency.tnd),
      );
    });

    test('a text recognition failure is passed on', () async {
      final scanner = FakeReceiptScanner()
        ..failure = const QuickInputFailure(QuickInputError.ocrFailed);
      final result = await ScanReceipt(scanner, read)(
        '/x.jpg',
        currency: Currency.tnd,
        today: _today,
      );
      expect(result, isA<Err<Object?, QuickInputFailure>>());
    });
  });
}
