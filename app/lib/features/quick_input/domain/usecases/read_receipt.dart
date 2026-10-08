import 'dart:async';

import '../../../../core/money/currency.dart';
import '../../../../core/result/result.dart';
import '../repositories/expense_llm.dart';
import '../value_objects/ocr_line.dart';
import '../value_objects/parse_method.dart';
import '../value_objects/parsed_item.dart';
import '../value_objects/quick_input_error.dart';
import '../value_objects/quick_input_failure.dart';
import '../value_objects/quick_parse.dart';
import '../value_objects/receipt_reading.dart';
import 'build_receipt_prompt.dart';
import 'extract_receipt.dart';
import 'group_receipt_rows.dart';
import 'parse_expense_text.dart';
import 'read_receipt_answer.dart';

/// A receipt's OCR lines → one item (the shop, the total) and its date, for
/// the confirmation sheet (ARCHITECTURE.md §8): rows rebuilt from the
/// boxes, the rule extractor, then the LLM when no total was named
/// (confidence below `ParseExpenseText.fallbackBelow`). Like phrases, a
/// failed, slow or invalid LLM answer keeps the rules' reading.
class ReadReceipt {
  const ReadReceipt(
    this._llm, {
    GroupReceiptRows rows = const GroupReceiptRows(),
    ExtractReceipt extract = const ExtractReceipt(),
    BuildReceiptPrompt prompt = const BuildReceiptPrompt(),
    ReadReceiptAnswer read = const ReadReceiptAnswer(),
    this.timeout = const Duration(seconds: 30),
  }) : _rows = rows,
       _extract = extract,
       _prompt = prompt,
       _read = read;

  final ExpenseLlm _llm;
  final GroupReceiptRows _rows;
  final ExtractReceipt _extract;
  final BuildReceiptPrompt _prompt;
  final ReadReceiptAnswer _read;
  final Duration timeout;

  Future<QuickParse> call(
    List<OcrLine> lines, {
    required Currency currency,
    required DateTime today,
  }) async {
    final rows = _rows(lines);
    final rules = _extract(rows, currency: currency, today: today);
    QuickParse parse(
      ReceiptReading reading,
      ParseMethod method, [
      QuickInputFailure? failure,
    ]) => QuickParse(
      text: rules.merchant.isEmpty ? 'Receipt' : rules.merchant,
      items: [
        if (reading.total case final total?)
          ParsedItem(
            label: rules.merchant,
            amount: total,
            confidence: reading.confidence,
          ),
      ],
      method: method,
      llmFailure: failure,
      date: reading.date ?? rules.date,
    );

    if (rows.isEmpty || rules.confidence >= ParseExpenseText.fallbackBelow) {
      return parse(rules, ParseMethod.rules);
    }
    if (!await _llm.isInstalled()) {
      return parse(
        rules,
        ParseMethod.rules,
        const QuickInputFailure(QuickInputError.modelNotInstalled),
      );
    }
    final answer = await _llm
        .complete(_prompt(rows))
        .then<Result<String, QuickInputFailure>>((answer) => answer)
        .timeout(
          timeout,
          onTimeout: () =>
              const Err(QuickInputFailure(QuickInputError.llmFailed)),
        );
    final read = switch (answer) {
      Ok(:final value) => _read(
        value,
        rows: rows,
        currency: currency,
        today: today,
      ),
      Err(:final failure) => Err<Never, QuickInputFailure>(failure),
    };
    return switch (read) {
      Ok(:final value) => parse(value, ParseMethod.llm),
      Err(:final failure) => parse(rules, ParseMethod.rules, failure),
    };
  }
}
