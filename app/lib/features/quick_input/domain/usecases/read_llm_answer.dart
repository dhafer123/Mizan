import 'dart:convert';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money_parser.dart';
import '../../../../core/result/result.dart';
import '../../../expenses/domain/usecases/validate_expense.dart';
import '../value_objects/expense_keywords.dart';
import '../value_objects/parsed_item.dart';
import '../value_objects/quick_input_error.dart';
import '../value_objects/quick_input_failure.dart';

/// Checks the LLM's answer against the fixed shape before anything uses it:
/// `{"items":[{"label": "...", "amount": "3.500"}]}`.
///
/// - Text around the JSON (a code fence, a sentence) is ignored.
/// - 1 to [maxItems] items. Each label is text of at most
///   `ValidateExpense.maxNoteLength`; each amount a string or number that
///   reads as more than 0 in the currency. Extra keys are ignored.
/// - **No invented items:** a label must share a word with the phrase.
///
/// Anything else rejects the whole answer, so the rules' reading is used.
/// The items still go to the confirmation sheet.
class ReadLlmAnswer {
  const ReadLlmAnswer();

  static const maxItems = 10;

  /// The LLM gives no confidence of its own; its items are confirmed by
  /// the user like every other.
  static const confidence = 70;

  Result<List<ParsedItem>, QuickInputFailure> call(
    String answer, {
    required String phrase,
    required Currency currency,
  }) {
    const invalid = Err<List<ParsedItem>, QuickInputFailure>(
      QuickInputFailure(QuickInputError.llmInvalid),
    );
    final start = answer.indexOf('{');
    final end = answer.lastIndexOf('}');
    if (start < 0 || end < start) return invalid;

    final Object? json;
    try {
      json = jsonDecode(answer.substring(start, end + 1));
    } on FormatException {
      return invalid;
    }
    if (json is! Map<String, Object?>) return invalid;
    final items = json['items'];
    if (items is! List<Object?> || items.isEmpty || items.length > maxItems) {
      return invalid;
    }

    final said = ExpenseKeywords.normalize(phrase);
    final read = <ParsedItem>[];
    for (final item in items) {
      if (item is! Map<String, Object?>) return invalid;
      final label = item['label'];
      final amount = item['amount'];
      if (label is! String) return invalid;
      final text = label.trim();
      if (text.length > ValidateExpense.maxNoteLength) return invalid;
      if (text.isNotEmpty && !_saidIn(text, said)) return invalid;

      final amountText = switch (amount) {
        String() => amount,
        int() => '$amount',
        double() when amount.isFinite => '$amount',
        _ => null,
      };
      if (amountText == null) return invalid;
      switch (const MoneyParser().parse(amountText, currency: currency)) {
        case Ok(:final value) when value.isPositive:
          read.add(
            ParsedItem(label: text, amount: value, confidence: confidence),
          );
        case _:
          return invalid;
      }
    }
    return Ok(read);
  }

  /// Whether a word of [label] (2+ letters) is in the normalized phrase.
  static bool _saidIn(String label, String said) =>
      ExpenseKeywords.normalize(label)
          .split(RegExp(r"[^\p{L}\p{N}']+", unicode: true))
          .any((word) => word.length >= 2 && said.contains(word));
}
