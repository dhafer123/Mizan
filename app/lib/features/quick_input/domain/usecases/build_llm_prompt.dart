import '../../../../core/money/currency.dart';

/// The instructions for the LLM tier: answer with JSON only, in a fixed
/// shape (`ReadLlmAnswer` checks it), with a few examples. Short, because
/// the model is small and every token costs time on the phone.
class BuildLlmPrompt {
  const BuildLlmPrompt();

  String call(String phrase, {required Currency currency}) {
    // An amount in thousandths of the major unit, written as the model
    // should: "1.500" in TND, "1.50" in EUR.
    String amount(int thousandths) {
      final major = thousandths ~/ 1000;
      final fraction = (thousandths % 1000)
          .toString()
          .padLeft(3, '0')
          .substring(0, currency.decimals);
      return currency.decimals == 0 ? '$major' : '$major.$fraction';
    }

    final money = currency == Currency.tnd
        ? '- "amount" is in dinars with a dot: "3.500". "dinar" = 1, '
              '"nos" = half, "alf" = 1 dinar. A bare number of 1000 or more '
              'is millimes: 3500 = "3.500".'
        : '- "amount" is in ${currency.code} with a dot: "${amount(3500)}".';
    return '''
You read expenses from what a student said or typed, in French, English or Tunisian Darija in Latin letters. Answer with JSON only:
{"items":[{"label":"coffee","amount":"${amount(1000)}"}]}
Rules:
- One item per thing paid for. "label" is the words from the phrase that name it.
$money
- Numbers in words: un/one/wa7ed 1, deux/two/zouz 2, trois/three/thletha 3, quatre/four/arb3a 4, cinq/five/khamsa 5, six/setta 6, sept/seven/sab3a 7, huit/eight/thmenya 8, neuf/nine/tes3a 9, dix/ten/3achra 10, vingt/twenty/3echrin 20.
Examples:
Phrase: kahwa b dinar w nos
{"items":[{"label":"kahwa","amount":"${amount(1500)}"}]}
Phrase: taxi trois dinars et deux cafés 5
{"items":[{"label":"taxi","amount":"${amount(3000)}"},{"label":"cafés","amount":"${amount(5000)}"}]}
Phrase: $phrase
''';
  }
}
