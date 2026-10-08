import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/quick_input/domain/usecases/parse_expense_text.dart';
import 'package:mizan/features/quick_input/domain/value_objects/expense_keywords.dart';
import 'package:mizan/features/quick_input/domain/value_objects/parsed_input.dart';

const _parse = ParseExpenseText();

ParsedInput _tnd(String text) => _parse(text, currency: Currency.tnd);

/// A phrase and what was meant: (label, amount in millimes) per item.
/// [hard] phrases are beyond the rules: they must come out below the
/// fallback threshold, so the LLM tier (task 5.5) gets them.
class _Case {
  const _Case(this.phrase, this.items, {this.hard = false});

  final String phrase;
  final List<(String, int)> items;
  final bool hard;
}

/// The rule parser's test set: English, French, Darija in Latin letters,
/// and mixes. The rules-only accuracy in METRICS.md is measured on it.
const _cases = [
  // English.
  _Case('coffee 3.5 and taxi 8', [('coffee', 3500), ('taxi', 8000)]),
  _Case('taxi 8', [('taxi', 8000)]),
  _Case('lunch 12.500', [('lunch', 12500)]),
  _Case('spent 12 on lunch', [('lunch', 12000)]),
  _Case('bought a sandwich for 4.5', [('sandwich', 4500)]),
  _Case('coffee 2.5, taxi 7, bread 0.250', [
    ('coffee', 2500),
    ('taxi', 7000),
    ('bread', 250),
  ]),
  _Case('netflix 15 dt', [('netflix', 15000)]),
  _Case('phone recharge 5', [('phone recharge', 5000)]),
  _Case('books 25 and photocopies 3', [
    ('books', 25000),
    ('photocopies', 3000),
  ]),
  _Case('8 taxi then 3 coffee', [('taxi', 8000), ('coffee', 3000)]),
  _Case('gym 70', [('gym', 70000)]),
  _Case('groceries 43,750', [('groceries', 43750)]),
  _Case('rent 450', [('rent', 450000)]),
  _Case('pizza 18 + juice 3', [('pizza', 18000), ('juice', 3000)]),
  _Case('movie 12dt and popcorn 6', [('movie', 12000), ('popcorn', 6000)]),
  // French.
  _Case('café 1.5 et taxi 8', [('café', 1500), ('taxi', 8000)]),
  _Case("j'ai payé 5 pour un café", [('café', 5000)]),
  _Case('taxi 8 dt et un café à 2,5', [('taxi', 8000), ('café', 2500)]),
  _Case('loyer 400', [('loyer', 400000)]),
  _Case('courses 32,400', [('courses', 32400)]),
  _Case('déjeuner 9 et thé 1,2', [('déjeuner', 9000), ('thé', 1200)]),
  _Case('3,5 croissant et 2 jus', [('croissant', 3500), ('jus', 2000)]),
  _Case('pharmacie 23.800', [('pharmacie', 23800)]),
  _Case('essence 20 dinars', [('essence', 20000)]),
  _Case('livre 35 dt, stylo 1.5', [('livre', 35000), ('stylo', 1500)]),
  _Case('cinéma 10 puis glace 4', [('cinéma', 10000), ('glace', 4000)]),
  _Case("l'eau 0.8", [('eau', 800)]),
  _Case('le métro 0,5', [('métro', 500)]),
  _Case('Café 2 DT.', [('Café', 2000)]),
  // Darija in Latin letters.
  _Case('kahwa 1.5 w kaskrout 3.5', [('kahwa', 1500), ('kaskrout', 3500)]),
  _Case('3.5 café w 8 taxi', [('café', 3500), ('taxi', 8000)]),
  _Case('kaskrout b 3500', [('kaskrout', 3500)]),
  _Case('9ahwa 1200', [('9ahwa', 1200)]),
  _Case('khallast 20 dt louage', [('louage', 20000)]),
  _Case('3cha 12 w chicha 6', [('3cha', 12000), ('chicha', 6000)]),
  _Case('louage 7 dinars w 500 millimes', [('louage', 7500)]),
  _Case('5obz 0.250 w lait 1.350', [('5obz', 250), ('lait', 1350)]),
  _Case('kra 350', [('kra', 350000)]),
  _Case('taxi 3d500', [('taxi', 3500)]),
  _Case('chrit ktob b 40', [('ktob', 40000)]),
  _Case('mlewi 2 dinars 500', [('mlewi', 2500)]),
  _Case('flexy 5 o kahwa 1.8', [('flexy', 5000), ('kahwa', 1800)]),
  _Case('lablebi 3 w 7anout 15', [('lablebi', 3000), ('7anout', 15000)]),
  _Case('metro 0.700 w kaskrout 4', [('metro', 700), ('kaskrout', 4000)]),
  _Case('hajjem 10', [('hajjem', 10000)]),
  _Case('kahwa 900 millimes', [('kahwa', 900)]),
  _Case('ftour 15.5', [('ftour', 15500)]),
  _Case('kahwa b 1500 w direct b 1800', [('kahwa', 1500), ('direct', 1800)]),
  // No separators, and mixes.
  _Case('coffee 3.5 taxi 8', [('coffee', 3500), ('taxi', 8000)]),
  _Case('3 coffee 8 taxi', [('coffee', 3000), ('taxi', 8000)]),
  _Case('café 2 croissant 1.2 jus 3', [
    ('café', 2000),
    ('croissant', 1200),
    ('jus', 3000),
  ]),
  _Case('taxi 8dt', [('taxi', 8000)]),
  _Case('coffee and croissant 5', [('coffee + croissant', 5000)]),
  // Hard: number words, no amount, no label, unreadable amounts.
  _Case('deux cafés 3 dt', [('deux cafés', 3000)], hard: true),
  _Case('kahwa b dinar w nos', [('kahwa', 1500)], hard: true),
  _Case('taxi trois dinars', [('taxi', 3000)], hard: true),
  _Case('khamsa dinars kaskrout', [('kaskrout', 5000)], hard: true),
  _Case('12', [('', 12000)], hard: true),
  _Case('2 cafés 3dt', [('2 cafés', 3000)], hard: true),
  _Case('taxi', [('taxi', 0)], hard: true),
  _Case('coffee 3.5555', [('coffee', 3555)], hard: true),
];

/// Whether [parsed] read exactly the [expected] items.
bool _matches(ParsedInput parsed, List<(String, int)> expected) =>
    parsed.items.length == expected.length &&
    [
      for (var i = 0; i < expected.length; i++)
        parsed.items[i].label == expected[i].$1 &&
            parsed.items[i].amount == Money(expected[i].$2, Currency.tnd),
    ].every((ok) => ok);

void main() {
  test('the test set has 50+ phrases', () {
    expect(_cases.length, greaterThanOrEqualTo(50));
  });

  group('phrases', () {
    for (final c in _cases) {
      test(c.phrase, () {
        final parsed = _tnd(c.phrase);
        if (c.hard) {
          expect(
            parsed.confidence,
            lessThan(ParseExpenseText.fallbackBelow),
            reason: '$parsed',
          );
        } else {
          expect(_matches(parsed, c.items), isTrue, reason: '$parsed');
          expect(
            parsed.confidence,
            greaterThanOrEqualTo(ParseExpenseText.fallbackBelow),
            reason: '$parsed',
          );
        }
      });
    }
  });

  test('rules-only accuracy, and no confident mistakes', () {
    var correct = 0;
    var confidentWrong = 0;
    for (final c in _cases) {
      final parsed = _tnd(c.phrase);
      final ok = _matches(parsed, c.items);
      if (ok) correct++;
      if (!ok && parsed.confidence >= ParseExpenseText.fallbackBelow) {
        confidentWrong++;
      }
    }
    final percent = (correct * 1000 / _cases.length).round() / 10;
    // Recorded in METRICS.md.
    // ignore: avoid_print
    print(
      'Rules only: $correct / ${_cases.length} correct ($percent%), '
      '$confidentWrong confidently wrong',
    );
    expect(confidentWrong, 0);
  });

  group('confidence', () {
    test('a known word is surer than an unknown one', () {
      final known = _tnd('taxi 8').items.single;
      final unknown = _tnd('zorblax 8').items.single;
      expect(known.confidence, 100);
      expect(unknown.confidence, lessThan(known.confidence));
      expect(unknown.confidence, greaterThanOrEqualTo(60));
    });

    test('a millime guess is less sure than an explicit amount', () {
      expect(
        _tnd('kahwa 1500').items.single.confidence,
        lessThan(_tnd('kahwa 1.5').items.single.confidence),
      );
    });

    test('a unit in another currency goes to the fallback', () {
      final parsed = _tnd('coffee 4€');
      expect(parsed.items.single.amount, const Money(4000, Currency.tnd));
      expect(parsed.confidence, lessThan(ParseExpenseText.fallbackBelow));
    });

    test('nothing to read is confidence 0', () {
      expect(_tnd('').items, isEmpty);
      expect(_tnd('').confidence, 0);
      expect(_tnd('hello there').confidence, 0);
    });
  });

  group('other currencies', () {
    test('bare whole numbers are never millimes outside TND', () {
      final parsed = _parse('coffee 1500', currency: Currency.eur);
      expect(parsed.items.single.amount, const Money(150000, Currency.eur));
    });

    test('euros with a sign or a word', () {
      final parsed = _parse(
        '€4.50 coffee and taxi 12 euros',
        currency: Currency.eur,
      );
      expect(parsed.items.map((i) => (i.label, i.amount.minorUnits)), [
        ('coffee', 450),
        ('taxi', 1200),
      ]);
      expect(parsed.confidence, 100);
    });
  });

  test('keywords are found with accents, case and plurals', () {
    expect(ExpenseKeywords.categoryOf('Café'), 'food');
    expect(ExpenseKeywords.categoryOf('les photocopies'), 'study');
    expect(ExpenseKeywords.categoryOf('tickets'), 'transport');
    expect(ExpenseKeywords.categoryOf('zorblax'), isNull);
  });

  group('properties', () {
    Glados(any.parserItems, ExploreConfig(numRuns: 1000)).test(
      'known items with amounts, joined by any separator, read back exactly',
      (sample) {
        final (phrase, items) = sample;
        final parsed = _tnd(phrase);
        expect(_matches(parsed, items), isTrue, reason: '"$phrase" → $parsed');
        expect(parsed.confidence, greaterThanOrEqualTo(60));
      },
    );

    Glados(any.letterOrDigits).test('any text: amounts above 0, '
        'confidence 0-100', (text) {
      final parsed = _tnd(text);
      for (final item in parsed.items) {
        expect(item.amount.isPositive, isTrue);
        expect(item.confidence, inInclusiveRange(0, 100));
      }
      expect(parsed.confidence, inInclusiveRange(0, 100));
    });
  });
}

extension _ParserAnys on Any {
  /// 1-4 known words with random amounts, written in random styles
  /// ("4.500", "4.5 dt", "4dt", "4 dinars 500"), label or amount first,
  /// joined by random separators: the phrase and what it means.
  Generator<(String, List<(String, int)>)> get parserItems => combine2(
    intInRange(1, 5),
    intInRange(0, 1 << 32),
    (int n, int seed) {
      final random = Random(seed);
      final words = ExpenseKeywords.categories.keys.toList();
      const separators = [' and ', ' et ', ' w ', ', ', ' + ', ' ; ', ' o '];
      final amountFirst = random.nextBool();
      final items = <(String, int)>[];
      final parts = <String>[];
      for (var i = 0; i < n; i++) {
        final word = words[random.nextInt(words.length)];
        final dinars = random.nextInt(500);
        final millimes = random.nextInt(1000);
        final total = dinars * 1000 + millimes;
        if (total == 0) continue;
        final amount = switch (random.nextInt(4)) {
          0 => '$dinars.${millimes.toString().padLeft(3, '0')}',
          1 => '$dinars,${millimes.toString().padLeft(3, '0')} dt',
          2 when millimes >= 100 => '$dinars dinars $millimes',
          _ => '${dinars}d${millimes.toString().padLeft(3, '0')}',
        };
        items.add((word, total));
        parts.add(amountFirst ? '$amount $word' : '$word $amount');
      }
      final phrase = StringBuffer();
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) phrase.write(separators[random.nextInt(separators.length)]);
        phrase.write(parts[i]);
      }
      return (phrase.toString(), items);
    },
  );
}
