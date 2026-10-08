import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/quick_input/domain/usecases/build_llm_prompt.dart';
import 'package:mizan/features/quick_input/domain/usecases/read_llm_answer.dart';
import 'package:mizan/features/quick_input/domain/value_objects/parsed_item.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';

void main() {
  const build = BuildLlmPrompt();

  test('ends with the phrase, and explains millimes in TND', () {
    final prompt = build('kahwa b alf', currency: Currency.tnd);
    expect(prompt.trimRight(), endsWith('Phrase: kahwa b alf'));
    expect(prompt, contains('3500 = "3.500"'));
    expect(prompt, contains('"amount":"1.500"'));
  });

  test('other currencies get their own decimals and no millimes', () {
    final prompt = build('coffee two', currency: Currency.eur);
    expect(prompt, contains('in EUR'));
    expect(prompt, contains('"amount":"1.50"'));
    expect(prompt, isNot(contains('millimes')));
  });

  test("the prompt's own examples pass ReadLlmAnswer", () {
    final prompt = build('x', currency: Currency.tnd);
    final examples = RegExp(r'Phrase: (.+)\n(\{.+\})').allMatches(prompt);
    expect(examples, hasLength(2));
    for (final m in examples) {
      expect(
        const ReadLlmAnswer()(m[2]!, phrase: m[1]!, currency: Currency.tnd),
        isA<Ok<List<ParsedItem>, QuickInputFailure>>(),
      );
    }
  });
}
