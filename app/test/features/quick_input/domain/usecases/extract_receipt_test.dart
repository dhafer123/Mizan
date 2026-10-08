import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/quick_input/domain/usecases/extract_receipt.dart';
import 'package:mizan/features/quick_input/domain/value_objects/receipt_reading.dart';

const _extract = ExtractReceipt();
final _today = DateTime.utc(2026, 10, 8, 14);

ReceiptReading _tnd(List<String> rows) =>
    _extract(rows, currency: Currency.tnd, today: _today);

Money _dt(int millimes) => Money(millimes, Currency.tnd);

/// Receipts as they come out of `GroupReceiptRows`: a name, the rows, the
/// total in millimes (null: none), the date.
final _receipts = <(String, List<String>, int?, DateTime?)>[
  (
    'supermarket, TOTAL TTC after HT and TVA',
    [
      'MONOPRIX MENZAH 6',
      'Tel: 71 234 567',
      '05/10/2026  18:42',
      'LAIT DELICE 1L  2 x 1,350  2,700',
      'PAIN DE MIE  1,900',
      'YAOURT  0,650',
      'TOTAL HT  4,428',
      'TVA 19%  0,822',
      'TOTAL TTC  5,250',
      'ESPECES  10,000',
      'RENDU  4,750',
    ],
    5250,
    DateTime.utc(2026, 10, 5),
  ),
  (
    'NET A PAYER beats TOTAL',
    [
      'Carrefour Market',
      'Date: 2026-10-01',
      'TOTAL  32,400',
      'REMISE  -2,000',
      'NET A PAYER  30,400',
    ],
    30400,
    DateTime.utc(2026, 10, 1),
  ),
  (
    'café, amount on the row under TOTAL',
    ['Café Le Baron', '07.10.26', '2 Express  3.000', 'TOTAL', '3.000 DT'],
    3000,
    DateTime.utc(2026, 10, 7),
  ),
  (
    'restaurant with a 2-decimal total',
    ['RESTAURANT EL ALI', '06/10/2026', 'Couscous 1  12.50', 'Total: 14.50'],
    14500,
    DateTime.utc(2026, 10, 6),
  ),
  (
    'pharmacy, MONTANT and a stamp',
    [
      'PHARMACIE CENTRALE',
      'Le 04-10-2026',
      'Doliprane  4,200',
      'Timbre fiscal  1,000',
      'MONTANT  5,200',
    ],
    5200,
    DateTime.utc(2026, 10, 4),
  ),
  (
    'item count is not the total',
    ['AZIZA', 'Total articles: 3', 'Total  7,950', 'Carte bancaire  7,950'],
    7950,
    null,
  ),
  (
    'subtotal and cash given are skipped',
    [
      'GENERALE',
      'Sous-total  18,000',
      'Total  21,420',
      'Cash  50,000',
      'Change  28,580',
    ],
    21420,
    null,
  ),
  (
    'whole amount with the currency first',
    ['Grocery', r'You saved: $3,50', r'Total:  $24'],
    24000,
    null,
  ),
  (
    'whole amount with a unit',
    ['Station AGIL', 'Sans plomb 20 L', 'TOTAL A PAYER 45 DT'],
    45000,
    null,
  ),
];

void main() {
  group('receipts', () {
    for (final (name, rows, total, date) in _receipts) {
      test(name, () {
        final reading = _tnd(rows);
        expect(reading.total, total == null ? isNull : _dt(total));
        expect(reading.date, date);
        expect(reading.confidence, greaterThanOrEqualTo(75));
      });
    }
  });

  test('the shop is the first row with letters at the top', () {
    expect(_tnd(_receipts.first.$2).merchant, 'MONOPRIX MENZAH 6');
    expect(
      _tnd(['***', '  Café Le Baron  ', 'TOTAL 3,000']).merchant,
      'Café Le Baron',
    );
  });

  group('with no named total', () {
    test('the largest amount, unsure', () {
      final reading = _tnd(['Kiosque', 'Chips  1,200', 'Eau  0,800', '2,000']);
      expect(reading.total, _dt(2000));
      expect(reading.confidence, ExtractReceipt.largestOnly);
    });

    test('a printed subtotal beats the largest price, still unsure', () {
      final reading = _tnd([
        'SUPERMARKET',
        'Item  19,200',
        'Item  15,000',
        'Sub Total  107,600',
        'Cash  200,000',
        'Change  92,400',
      ]);
      expect(reading.total, _dt(107600));
      expect(reading.confidence, ExtractReceipt.subtotalOnly);
      expect(reading.confidence, lessThan(60));
    });

    test('nothing that looks like money: no total', () {
      final reading = _tnd(['Merci de votre visite', 'Tel 71 234 567']);
      expect(reading.total, isNull);
      expect(reading.confidence, 0);
    });
  });

  group('amounts', () {
    List<int> amounts(String row, [Currency currency = Currency.tnd]) => [
      for (final m in ExtractReceipt.amountsIn(row, currency: currency))
        m.minorUnits,
    ];

    test('decimals with a dot or a comma, units, grouping', () {
      expect(amounts('12,500'), [12500]);
      expect(amounts('12.500 DT'), [12500]);
      expect(amounts('12.5'), [12500]);
      expect(amounts('1.234,500'), [1234500]);
      expect(amounts('45 DT'), [45000]);
      expect(amounts('2 x 1,350  2,700'), [1350, 2700]);
      expect(amounts(r'Total: $24'), [24000]);
      expect(amounts('DT 5'), [5000]);
      expect(amounts(r'$3,50'), [3500]);
    });

    test('not codes, quantities, phones, times, dates or percentages', () {
      expect(amounts('Ref 123456'), isEmpty);
      expect(amounts('Qte 2'), isEmpty);
      expect(amounts('Tel 71 234 567'), isEmpty);
      expect(amounts('18:42'), isEmpty);
      expect(amounts('05/10/2026'), isEmpty);
      expect(amounts('TVA 19,00 %'), isEmpty);
    });

    test('in euros, 3 digits after a separator are thousands', () {
      expect(amounts('14,50', Currency.eur), [1450]);
      expect(amounts('1.234 €', Currency.eur), [123400]);
      expect(amounts('12,500', Currency.eur), isEmpty);
    });
  });

  group('dates', () {
    DateTime? date(String row) => _tnd([row]).date;

    test('day first, two or four digit years, ISO', () {
      expect(date('08/10/2026'), DateTime.utc(2026, 10, 8));
      expect(date('8-10-26'), DateTime.utc(2026, 10, 8));
      expect(date('2026-09-30'), DateTime.utc(2026, 9, 30));
    });

    test('impossible, future or older than a year: ignored', () {
      expect(date('31/02/2026'), isNull);
      expect(date('09/10/2026'), isNull); // Tomorrow.
      expect(date('01/09/2025'), isNull);
    });
  });

  group('properties', () {
    Glados2(any.intInRange(1, 9999999), any.intInRange(0, 3)).test(
      'a printed amount reads back exactly',
      (millimes, style) {
        final major = millimes ~/ 1000;
        final minor = (millimes % 1000).toString().padLeft(3, '0');
        final grouped = major >= 1000
            ? '${major ~/ 1000}.${(major % 1000).toString().padLeft(3, '0')}'
            : '$major';
        final text = switch (style) {
          0 => '$major,$minor',
          1 => '$major.$minor DT',
          2 => 'TOTAL  $grouped,$minor',
          _ => 'Montant: $major,$minor TND',
        };
        expect(ExtractReceipt.amountsIn(text, currency: Currency.tnd), [
          _dt(millimes),
        ]);
      },
    );

    Glados(any.list(any.letterOrDigits)).test(
      'any rows: the total, if any, is an amount printed on them',
      (rows) {
        final reading = _tnd(rows);
        if (reading.total case final total?) {
          final printed = {
            for (final row in rows)
              ...ExtractReceipt.amountsIn(row, currency: Currency.tnd),
          };
          expect(printed, contains(total));
          expect(total.isPositive, isTrue);
        }
      },
    );
  });
}
