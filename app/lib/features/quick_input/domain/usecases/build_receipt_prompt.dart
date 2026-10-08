/// The instructions for the LLM tier on a receipt: find the total paid and
/// the date, answer with JSON only (`ReadReceiptAnswer` checks it).
///
/// The receipt is cut to its first [headRows] rows (shop, date) and last
/// [tailRows] (totals) so the prompt fits the small model's context.
class BuildReceiptPrompt {
  const BuildReceiptPrompt();

  static const headRows = 6;
  static const tailRows = 30;

  String call(List<String> rows) {
    final kept = rows.length <= headRows + tailRows
        ? rows
        : [...rows.take(headRows), '...', ...rows.skip(rows.length - tailRows)];
    return '''
This is a shop receipt read by OCR, one printed row per line. Find the total paid and the date. Answer with JSON only:
{"total":"12.500","date":"2026-10-05"}
The total is the amount to pay (TOTAL, TOTAL TTC, NET A PAYER, MONTANT), written as on the receipt, not a subtotal, the tax or the cash given. Use null for what you can't find.
Receipt:
${kept.join('\n')}
''';
  }
}
