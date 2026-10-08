import 'dart:convert';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_parser.dart';
import '../../../../core/result/result.dart';
import '../value_objects/quick_input_error.dart';
import '../value_objects/quick_input_failure.dart';
import '../value_objects/receipt_reading.dart';
import 'extract_receipt.dart';

/// Checks the LLM's answer about a receipt: `{"total": "12.500", "date":
/// "2026-10-05"}`, with text around the JSON ignored.
///
/// - **No invented total:** it must be one of the amounts printed on the
///   receipt ([ExtractReceipt.amountsIn]).
/// - The date is kept only if it is real, not in the future and at most a
///   year old; otherwise it is dropped (the user sets it).
///
/// Anything else rejects the answer, so the rules' reading is used.
class ReadReceiptAnswer {
  const ReadReceiptAnswer();

  /// The LLM gives no confidence of its own; the user confirms the total.
  static const confidence = 70;

  Result<ReceiptReading, QuickInputFailure> call(
    String answer, {
    required List<String> rows,
    required Currency currency,
    required DateTime today,
  }) {
    const invalid = Err<ReceiptReading, QuickInputFailure>(
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

    final totalText = switch (json['total']) {
      final String text => text,
      final int number => '$number',
      final double number when number.isFinite => '$number',
      _ => null,
    };
    if (totalText == null) return invalid;
    final Money total;
    switch (const MoneyParser().parse(totalText, currency: currency)) {
      case Ok(:final value) when value.isPositive:
        total = value;
      case _:
        return invalid;
    }
    final printed = {
      for (final row in rows)
        ...ExtractReceipt.amountsIn(row, currency: currency),
    };
    if (!printed.contains(total)) return invalid;

    return Ok(
      ReceiptReading(
        total: total,
        date: _date(json['date'], today),
        confidence: confidence,
      ),
    );
  }

  static DateTime? _date(Object? value, DateTime today) {
    if (value is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
    if (m == null) return null;
    return ExtractReceipt.plausibleDate(
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3]!),
      today: today,
    );
  }
}
