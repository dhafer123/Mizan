// Task 5.6's accuracy check, on the phone: OCR + extractor (+ LLM) on real
// receipt photos.
//
// WARNING: flutter test uninstalls the app before and after the run,
// wiping the phone's local Mizan data and the downloaded assistant. Use a
// phone whose data is synced, or a spare one.
//
// 1. Put 30+ photos and truth.csv in receipts_eval/ at the repo root (git
//    ignores it). truth.csv, one row per photo, date optional:
//      file,total,date
//      monoprix_1.jpg,5.250,2026-10-05
// 2. Start: flutter test integration_test/receipt_eval_test.dart (phone
//    connected). When it prints "Waiting for receipts", copy them into the
//    app (the test build is debuggable, so run-as works):
//      adb push receipts_eval/. /data/local/tmp/receipts/
//      adb shell run-as com.mizan.mizan sh -c 'cp /data/local/tmp/receipts/* files/receipts/'
// 3. The rules + LLM column runs only if the assistant is on the phone;
//    the reinstall removes it, so it usually says "not run".
// 4. Copy the printed summary line into METRICS.md.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money_parser.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/quick_input/data/platform/gemma_expense_llm.dart';
import 'package:mizan/features/quick_input/data/platform/mlkit_receipt_scanner.dart';
import 'package:mizan/features/quick_input/domain/repositories/expense_llm.dart';
import 'package:mizan/features/quick_input/domain/usecases/read_receipt.dart';
import 'package:mizan/features/quick_input/domain/value_objects/parse_method.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_error.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';

/// The app's own (internal) files folder, which it can always create.
const _folder = '/data/user/0/com.mizan.mizan/files/receipts';

/// The rules alone: an LLM that is never there.
class _NoLlm implements ExpenseLlm {
  @override
  Future<bool> isInstalled() async => false;

  @override
  Stream<Result<int, QuickInputFailure>> install() => const Stream.empty();

  @override
  Future<Result<void, QuickInputFailure>> uninstall() async => const Ok(null);

  @override
  Future<Result<String, QuickInputFailure>> complete(String prompt) async =>
      const Err(QuickInputFailure(QuickInputError.modelNotInstalled));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('receipts: total accuracy, rules vs rules + LLM', (tester) async {
    // flutter test reinstalls the app, which wipes this folder: create it,
    // then wait for the receipts to be pushed (step 2) while the test runs.
    Directory(_folder).createSync(recursive: true);
    final truth = File('$_folder/truth.csv');
    // ignore: avoid_print
    print('Waiting for receipts in $_folder');
    for (var i = 0; i < 180 && !truth.existsSync(); i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    expect(truth.existsSync(), isTrue, reason: 'Push receipts_eval/ first.');
    // Let the rest of the push land.
    await Future<void>.delayed(const Duration(seconds: 3));
    final rows = [
      for (final line in truth.readAsLinesSync().skip(1))
        if (line.trim().isNotEmpty)
          line.split(',').map((c) => c.trim()).toList(),
    ];
    // METRICS.md needs 30+ real receipts; fewer is only a smoke test.
    final smoke = rows.length < 30;

    final scanner = MlKitReceiptScanner();
    final llm = GemmaExpenseLlm();
    final hasLlm = await llm.isInstalled();
    final rulesOnly = ReadReceipt(_NoLlm());
    final both = ReadReceipt(llm, timeout: const Duration(seconds: 60));
    final today = DateTime.now();

    var rulesRight = 0;
    var bothRight = 0;
    var datesRight = 0;
    var datesKnown = 0;
    final times = <int>[];
    for (final row in rows) {
      final file = row[0];
      final total = switch (const MoneyParser().parse(
        row[1],
        currency: Currency.tnd,
      )) {
        Ok(:final value) => value,
        Err() => throw StateError('Bad total for $file: ${row[1]}'),
      };
      final date = row.length > 2 && row[2].isNotEmpty
          ? DateTime.parse('${row[2]}T00:00:00Z')
          : null;

      final stopwatch = Stopwatch()..start();
      final lines = switch (await scanner.read('$_folder/$file')) {
        Ok(:final value) => value,
        Err() => const <Never>[],
      };
      final rules = await rulesOnly(
        lines,
        currency: Currency.tnd,
        today: today,
      );
      stopwatch.stop();
      times.add(stopwatch.elapsedMilliseconds);
      final withLlm = hasLlm
          ? await both(lines, currency: Currency.tnd, today: today)
          : rules;

      final rulesOk = rules.items.firstOrNull?.amount == total;
      final bothOk = withLlm.items.firstOrNull?.amount == total;
      if (rulesOk) rulesRight++;
      if (bothOk) bothRight++;
      if (date != null) {
        datesKnown++;
        if (withLlm.date == date) datesRight++;
      }
      // ignore: avoid_print
      print(
        '${rulesOk ? 'R' : '-'}${bothOk ? 'B' : '-'} '
        '${withLlm.method == ParseMethod.llm ? 'llm ' : '    '}'
        '$file: want ${row[1]}, got '
        '${withLlm.items.firstOrNull?.amount.minorUnits ?? '-'} '
        '(${lines.length} lines)',
      );
    }

    times.sort();
    final n = rows.length;
    String pct(int right, int of) =>
        of == 0 ? '-' : '${(right * 1000 / of).round() / 10}%';
    // ignore: avoid_print
    print(
      '${smoke ? 'SMOKE TEST (under 30, not for METRICS) ' : ''}'
      'Receipts $n: total right, rules only $rulesRight/$n '
      '(${pct(rulesRight, n)}), rules + LLM '
      '${hasLlm ? '$bothRight/$n (${pct(bothRight, n)})' : 'not run (no model)'}; '
      'date right $datesRight/$datesKnown (${pct(datesRight, datesKnown)}); '
      'median OCR + rules ${times[times.length ~/ 2]} ms',
    );
  });
}
