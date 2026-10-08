import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/quick_input/domain/usecases/parse_quick_input.dart';
import 'package:mizan/features/quick_input/domain/value_objects/parse_method.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_error.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';

import '../../../../support/fake_expense_llm.dart';

const _sure = 'kahwa 1.5 w taxi 8';
const _unsure = 'kahwa b dinar w nos';
const _answer = '{"items":[{"label":"kahwa","amount":"1.500"}]}';

void main() {
  late FakeExpenseLlm llm;
  late ParseQuickInput parse;

  setUp(() {
    llm = FakeExpenseLlm(answer: const Ok(_answer));
    parse = ParseQuickInput(llm, timeout: const Duration(milliseconds: 50));
  });

  test('sure rules are used without asking the LLM', () async {
    final result = await parse(_sure, currency: Currency.tnd);
    expect(result.method, ParseMethod.rules);
    expect(result.items, hasLength(2));
    expect(result.llmFailure, isNull);
    expect(llm.prompts, isEmpty);
  });

  test('unsure rules ask the LLM, and its checked answer is used', () async {
    final result = await parse(_unsure, currency: Currency.tnd);
    expect(result.method, ParseMethod.llm);
    expect(result.items.single.label, 'kahwa');
    expect(result.items.single.amount, const Money(1500, Currency.tnd));
    expect(llm.prompts.single, contains('Phrase: $_unsure'));
    expect(result.text, _unsure);
  });

  group('the rules stand, with the reason, when the LLM', () {
    Future<void> expectRules(QuickInputError error) async {
      final result = await parse(_unsure, currency: Currency.tnd);
      expect(result.method, ParseMethod.rules);
      expect(result.llmFailure, QuickInputFailure(error));
    }

    test('is not downloaded', () async {
      llm.installed = false;
      await expectRules(QuickInputError.modelNotInstalled);
      expect(llm.prompts, isEmpty);
    });

    test('fails', () async {
      llm.answer = const Err(QuickInputFailure(QuickInputError.llmFailed));
      await expectRules(QuickInputError.llmFailed);
    });

    test('takes too long', () async {
      llm.answer = null; // Never answers.
      await expectRules(QuickInputError.llmFailed);
    });

    test('answers nonsense', () async {
      llm.answer = const Ok('{"items":[{"label":"pizza","amount":"99"}]}');
      await expectRules(QuickInputError.llmInvalid);
    });
  });

  test('empty text reads nothing and asks no one', () async {
    final result = await parse('   ', currency: Currency.tnd);
    expect(result.items, isEmpty);
    expect(result.method, ParseMethod.rules);
    expect(llm.prompts, isEmpty);
  });
}
