// Task 5.5's accuracy check, on the phone with the real assistant model:
// rules only vs rules + LLM on the held-out phrases (held_out_phrases.dart).
//
// WARNING: flutter test uninstalls the app before and after the run,
// wiping the phone's local Mizan data and the downloaded assistant. Use a
// phone whose data is synced, or a spare one.
//
// 1. Put the phone on Wi-Fi: the fresh test build downloads the assistant
//    (~550 MB) before it starts.
// 2. With the phone connected: flutter test integration_test/quick_input_eval_test.dart
//    It runs in debug mode, so the printed LLM time is only a guide; the
//    METRICS timing comes from the release app (Settings → Voice timings).
// 3. Copy the printed summary line into METRICS.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/quick_input/data/platform/gemma_expense_llm.dart';
import 'package:mizan/features/quick_input/domain/usecases/parse_expense_text.dart';
import 'package:mizan/features/quick_input/domain/usecases/parse_quick_input.dart';
import 'package:mizan/features/quick_input/domain/value_objects/expense_keywords.dart';
import 'package:mizan/features/quick_input/domain/value_objects/parse_method.dart';
import 'package:mizan/features/quick_input/domain/value_objects/parsed_item.dart';

import 'held_out_phrases.dart';

/// Same items, in order: equal amounts, and labels that match loosely
/// (no accents or case; one contains the other).
bool _matches(List<ParsedItem> items, List<(String, int)> expected) {
  if (items.length != expected.length) return false;
  for (var i = 0; i < items.length; i++) {
    final (label, millimes) = expected[i];
    if (items[i].amount != Money(millimes, Currency.tnd)) return false;
    final got = ExpenseKeywords.normalize(items[i].label.trim());
    final want = ExpenseKeywords.normalize(label.trim());
    if (!got.contains(want) && !want.contains(got)) return false;
  }
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('held-out phrases: rules only vs rules + LLM', (tester) async {
    expect(
      heldOutPhrases.length,
      greaterThanOrEqualTo(30),
      reason: 'Write your 30 phrases in integration_test/held_out_phrases.dart',
    );
    final llm = GemmaExpenseLlm();
    if (!await llm.isInstalled()) {
      // ignore: avoid_print
      print('Downloading the assistant (~550 MB)...');
      await llm.install().drain<void>();
    }
    expect(
      await llm.isInstalled(),
      isTrue,
      reason: "The assistant didn't download. Check the phone's connection.",
    );
    final both = ParseQuickInput(llm, timeout: const Duration(seconds: 60));

    var rulesRight = 0;
    var bothRight = 0;
    var asked = 0;
    final llmTimes = <int>[];
    for (final (phrase, expected) in heldOutPhrases) {
      final rules = const ParseExpenseText()(phrase, currency: Currency.tnd);
      final rulesOk = _matches(rules.items, expected);
      if (rulesOk) rulesRight++;

      final stopwatch = Stopwatch()..start();
      final parse = await both(phrase, currency: Currency.tnd);
      stopwatch.stop();
      final bothOk = _matches(parse.items, expected);
      if (bothOk) bothRight++;
      if (rules.confidence < ParseExpenseText.fallbackBelow) {
        asked++;
        llmTimes.add(stopwatch.elapsedMilliseconds);
      }
      // ignore: avoid_print
      print(
        '${rulesOk ? 'R' : '-'}${bothOk ? 'B' : '-'} '
        '${parse.method == ParseMethod.llm ? 'llm ' : '    '}'
        '"$phrase" → ${[for (final i in parse.items) '${i.label} ${i.amount.minorUnits}']}'
        '${parse.llmFailure == null ? '' : ' (${parse.llmFailure!.error.name})'}',
      );
    }

    llmTimes.sort();
    final n = heldOutPhrases.length;
    String pct(int right) => '${(right * 1000 / n).round() / 10}%';
    // ignore: avoid_print
    print(
      'Held-out $n: rules only $rulesRight/$n (${pct(rulesRight)}), '
      'rules + LLM $bothRight/$n (${pct(bothRight)}); LLM asked on $asked, '
      'median LLM reading ${llmTimes.isEmpty ? '-' : '${llmTimes[llmTimes.length ~/ 2]} ms'}',
    );
  });
}
