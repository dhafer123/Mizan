import '../../../../core/clock/calendar_day.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../value_objects/expense_keywords.dart';
import '../value_objects/receipt_reading.dart';

/// Finds the total, the date and the shop on a receipt's rows (from
/// `GroupReceiptRows`), with fixed rules for French, English and Tunisian
/// receipts (ARCHITECTURE.md §8).
///
/// - **Total:** the amount on a row naming it ("NET A PAYER", "TOTAL TTC",
///   "TOTAL", "MONTANT"), or on the row below when the row has none. Rows
///   about something else are skipped: subtotals, tax, discounts, the cash
///   given and change, item counts. The strongest name wins, then the
///   largest amount. With no named total, the largest amount on the
///   receipt, with low confidence (the LLM tier can try then); a printed
///   subtotal beats that guess when it's all there is.
/// - **Amounts** need decimals ("12.500", "12,50", "1 234,500"), or a
///   currency unit before or after it ("12 DT", "$24"), so prices are told
///   from codes, quantities and phone numbers.
/// - **Date:** the first day/month/year (or ISO) date that is real, not in
///   the future and at most a year old.
/// - **Shop:** the first row at the top with a few letters.
class ExtractReceipt {
  const ExtractReceipt();

  /// Confidence for a total from a strong or a plain name, or from the
  /// largest amount alone.
  static const strongTotal = 90;
  static const plainTotal = 75;
  static const largestOnly = 40;

  /// A subtotal, when no row names the total: likely it, but unsure.
  static const subtotalOnly = 50;

  static const _strong = [
    'net a payer',
    'total a payer',
    'montant a payer',
    'reste a payer',
    'total ttc',
    'montant ttc',
    'grand total',
    'amount due',
    'total due',
    'a payer',
  ];
  static const _plain = ['total', 'montant', 'somme', 'ttc', 'net'];
  static const _subtotal = [
    'sous total',
    'sous-total',
    'subtotal',
    'sub total',
  ];

  /// Rows with these are about something other than the amount paid.
  static const _other = [
    'sous total',
    'sous-total',
    'subtotal',
    'sub total',
    'total ht',
    'ht',
    'tva',
    'vat',
    'tax',
    'remise',
    'discount',
    'rendu',
    'monnaie',
    'change',
    'especes',
    'espece',
    'cash',
    'recu',
    'carte',
    'cb',
    'credit',
    'articles',
    'article',
    'items',
    'qte',
    'quantite',
    'nb',
    'nombre',
    'points',
    'fidelite',
  ];

  ReceiptReading call(
    List<String> rows, {
    required Currency currency,
    required DateTime today,
  }) {
    final keys = [for (final row in rows) ExpenseKeywords.normalize(row)];
    final day0 = today.calendarDay;

    // (strength, amount, row) for each named total.
    final named = <(int, Money, int)>[];
    for (var i = 0; i < rows.length; i++) {
      final strength = _hasAny(keys[i], _strong)
          ? strongTotal
          : _hasAny(keys[i], _plain)
          ? plainTotal
          : 0;
      if (strength == 0 || _hasAny(keys[i], _other)) continue;
      final amounts = _amountsHereOrBelow(rows, keys, i, currency);
      if (amounts.isNotEmpty) named.add((strength, amounts.last, i));
    }

    // Subtotals, for when nothing names the total.
    final subtotals = <Money>[
      for (var i = 0; i < rows.length; i++)
        if (_hasAny(keys[i], _subtotal))
          ?_amountsHereOrBelow(rows, keys, i, currency).lastOrNull,
    ];

    final everything = [
      for (var i = 0; i < rows.length; i++)
        if (!_hasAny(keys[i], _other))
          ...amountsIn(rows[i], currency: currency),
    ];
    Money? largest;
    for (final amount in everything) {
      if (largest == null || amount > largest) largest = amount;
    }

    Money? total;
    var confidence = 0;
    if (named.isNotEmpty) {
      named.sort((a, b) {
        final byStrength = b.$1.compareTo(a.$1);
        return byStrength != 0 ? byStrength : b.$2.compareTo(a.$2);
      });
      total = named.first.$2;
      confidence = named.first.$1;
    } else if (subtotals.isNotEmpty) {
      total = subtotals.last;
      confidence = subtotalOnly;
    } else if (largest != null) {
      total = largest;
      confidence = largestOnly;
    }

    return ReceiptReading(
      total: total,
      date: _date(rows, day0),
      merchant: _merchant(rows),
      confidence: confidence,
    );
  }

  /// The amounts on row [i], or on the row below when it has none (and
  /// isn't about something else).
  static List<Money> _amountsHereOrBelow(
    List<String> rows,
    List<String> keys,
    int i,
    Currency currency,
  ) {
    final here = amountsIn(rows[i], currency: currency);
    if (here.isNotEmpty || i + 1 >= rows.length) return here;
    if (_hasAny(keys[i + 1], _other)) return here;
    return amountsIn(rows[i + 1], currency: currency);
  }

  /// The amounts printed on [row], left to right: with decimals, or whole
  /// with a currency unit. Not percentages.
  static List<Money> amountsIn(String row, {required Currency currency}) {
    final found = <Money>[];
    for (final m in _amount.allMatches(row)) {
      final number = m[2]!;
      final after = row.substring(m.end).trimLeft().toLowerCase();
      if (after.startsWith('%')) continue;
      final money = _read(number, currency, unit: m[1] != null || m[3] != null);
      if (money != null && money.isPositive) found.add(money);
    }
    return found;
  }

  /// An optional unit before ("$24", "DT 5"), a number (digits with
  /// optional "." or "," grouping and a decimal part), an optional unit
  /// after. Spaces never group: "2 150.000" is a quantity and a price.
  static final _amount = RegExp(
    r'(?:(\$|€|(?<![a-z])(?:dt|tnd)(?![a-z]))\s*)?'
    r'(?<![\d.,/:])(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,3})?|\d+(?:[.,]\d{1,3})?)'
    r'(?![\d/:])\s*(dt|tnd|d|€|eur|\$|usd)?(?![a-z])',
    caseSensitive: false,
  );

  /// [number] in minor units. The last "." or "," is the decimal point if
  /// at most the currency's decimals follow it ("12.500" is 12.5 DT, but
  /// "1.234" in EUR is 1234); other separators group thousands. A whole
  /// number counts only with a unit.
  static Money? _read(String number, Currency currency, {required bool unit}) {
    final decimal = RegExp(r'[.,](\d{1,3})$').firstMatch(number);
    final isDecimal =
        decimal != null && decimal[1]!.length <= currency.decimals;
    if (!isDecimal && !unit) return null;
    final whole = (isDecimal ? number.substring(0, decimal.start) : number)
        .replaceAll(RegExp('[.,]'), '');
    if (whole.isEmpty || whole.length > 9) return null;
    final minor = isDecimal
        ? int.parse(decimal[1]!.padRight(currency.decimals, '0'))
        : 0;
    return Money(int.parse(whole) * currency.minorPerMajor + minor, currency);
  }

  static final _dmy = RegExp(
    r'(?<!\d)(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})(?!\d)',
  );
  static final _ymd = RegExp(r'(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)');

  static DateTime? _date(List<String> rows, DateTime today) {
    for (final row in rows) {
      for (final m in _ymd.allMatches(row)) {
        final date = plausibleDate(
          int.parse(m[1]!),
          int.parse(m[2]!),
          int.parse(m[3]!),
          today: today,
        );
        if (date != null) return date;
      }
      for (final m in _dmy.allMatches(row)) {
        var year = int.parse(m[3]!);
        if (year < 100) year += 2000;
        final date = plausibleDate(
          year,
          int.parse(m[2]!),
          int.parse(m[1]!),
          today: today,
        );
        if (date != null) return date;
      }
    }
    return null;
  }

  /// The calendar day, if it exists, isn't after [today] and is at most a
  /// year before it; else null.
  static DateTime? plausibleDate(
    int year,
    int month,
    int day, {
    required DateTime today,
  }) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime.utc(year, month, day);
    if (date.month != month || date.day != day) return null; // 31/02
    final day0 = today.calendarDay;
    if (date.isAfter(day0)) return null;
    if (day0.difference(date).inDays > 366) return null;
    return date;
  }

  static String _merchant(List<String> rows) {
    for (final row in rows.take(5)) {
      final letters = RegExp(r'\p{L}', unicode: true).allMatches(row).length;
      if (letters < 3) continue;
      if (_hasAny(ExpenseKeywords.normalize(row), [..._strong, ..._plain])) {
        continue;
      }
      final name = row
          .replaceAll(
            RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
            '',
          )
          .replaceAll(RegExp(r'\s+'), ' ');
      return name.length > 40 ? name.substring(0, 40).trimRight() : name;
    }
    return '';
  }

  /// Whether [key] holds one of [words] as whole words.
  static bool _hasAny(String key, List<String> words) => words.any(
    (w) => RegExp('(?<![a-z0-9])${RegExp.escape(w)}(?![a-z0-9])').hasMatch(key),
  );
}
