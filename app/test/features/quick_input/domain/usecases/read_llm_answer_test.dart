import 'dart:convert';

import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/quick_input/domain/usecases/read_llm_answer.dart';
import 'package:mizan/features/quick_input/domain/value_objects/parsed_item.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_error.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';

const _read = ReadLlmAnswer();
const _invalid = Err<List<ParsedItem>, QuickInputFailure>(
  QuickInputFailure(QuickInputError.llmInvalid),
);

Result<List<ParsedItem>, QuickInputFailure> _tnd(
  String answer, {
  String phrase = 'kahwa b dinar w nos w taxi trois',
}) => _read(answer, phrase: phrase, currency: Currency.tnd);

void main() {
  test('reads items with string or number amounts', () {
    final read = _tnd(
      '{"items":[{"label":"kahwa","amount":"1.500"},'
      '{"label":"taxi","amount":3}]}',
    );
    expect(read, isA<Ok<List<ParsedItem>, QuickInputFailure>>());
    final items = read.valueOrNull!;
    expect(items.map((i) => (i.label, i.amount)), [
      ('kahwa', const Money(1500, Currency.tnd)),
      ('taxi', const Money(3000, Currency.tnd)),
    ]);
    expect(
      items.every((i) => i.confidence == ReadLlmAnswer.confidence),
      isTrue,
    );
  });

  test('ignores text and code fences around the JSON, and extra keys', () {
    final read = _tnd(
      'Sure! ```json\n{"items":[{"label":"kahwa","amount":"1.5",'
      '"category":"food"}]}\n```',
    );
    expect(read.valueOrNull?.single.amount, const Money(1500, Currency.tnd));
  });

  test('a decimal number amount reads without float drift', () {
    expect(
      _tnd(
        '{"items":[{"label":"kahwa","amount":1.5}]}',
      ).valueOrNull?.single.amount,
      const Money(1500, Currency.tnd),
    );
  });

  group('rejects', () {
    final cases = {
      'no JSON': 'I could not read that.',
      'broken JSON': '{"items":[{"label":"kahwa","amount":"1.5"}',
      'not an object': '[{"label":"kahwa","amount":"1.5"}]',
      'no items': '{"items":[]}',
      'items not a list': '{"items":{"label":"kahwa"}}',
      'an item not an object': '{"items":["kahwa 1.5"]}',
      'a label not text': '{"items":[{"label":5,"amount":"1.5"}]}',
      'a missing amount': '{"items":[{"label":"kahwa"}]}',
      'a zero amount': '{"items":[{"label":"kahwa","amount":"0"}]}',
      'a negative amount': '{"items":[{"label":"kahwa","amount":"-2"}]}',
      'an amount in words': '{"items":[{"label":"kahwa","amount":"two"}]}',
      'too many decimals': '{"items":[{"label":"kahwa","amount":"1.5555"}]}',
      'a boolean amount': '{"items":[{"label":"kahwa","amount":true}]}',
      'an invented label': '{"items":[{"label":"pizza","amount":"12"}]}',
      'a label too long':
          '{"items":[{"label":"kahwa ${'x' * 200}","amount":"1"}]}',
      'too many items':
          '{"items":[${List.filled(11, '{"label":"taxi","amount":"1"}').join(',')}]}',
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      test(key, () => expect(_tnd(value), _invalid));
    }
  });

  test('an empty label is allowed: the user names it on the sheet', () {
    expect(
      _tnd('{"items":[{"label":"","amount":"3"}]}').valueOrNull?.single.label,
      '',
    );
  });

  test('a label matches the phrase without accents or case', () {
    expect(
      _read(
        '{"items":[{"label":"Café","amount":"2"}]}',
        phrase: 'deux cafes',
        currency: Currency.tnd,
      ),
      isA<Ok<List<ParsedItem>, QuickInputFailure>>(),
    );
  });

  group('properties', () {
    Glados(any.letterOrDigits).test('any answer: no throw, and only amounts '
        'above 0', (answer) {
      final read = _tnd(answer);
      if (read case Ok(:final value)) {
        expect(value.every((i) => i.amount.isPositive), isTrue);
      }
    });

    Glados2(any.intInRange(1, 10), any.intInRange(1, 1000000000)).test(
      'well-formed items said in the phrase read back exactly',
      (count, seed) {
        final amounts = [
          for (var i = 0; i < count; i++) 1 + (seed * (i + 7)) % 999999,
        ];
        final labels = [for (var i = 0; i < count; i++) 'item$i'];
        String text(int minor) =>
            '${minor ~/ 1000}.${(minor % 1000).toString().padLeft(3, '0')}';
        final answer = jsonEncode({
          'items': [
            for (var i = 0; i < count; i++)
              {'label': labels[i], 'amount': text(amounts[i])},
          ],
        });
        final read = _read(
          answer,
          phrase: labels.join(' w '),
          currency: Currency.tnd,
        ).valueOrNull!;
        expect(read.map((i) => i.label), labels);
        expect(read.map((i) => i.amount.minorUnits), amounts);
      },
    );
  });
}
