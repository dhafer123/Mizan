import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_parser.dart';
import '../../../../core/result/result.dart';
import '../value_objects/expense_keywords.dart';
import '../value_objects/parsed_input.dart';
import '../value_objects/parsed_item.dart';

/// The first tier of quick input (ARCHITECTURE.md §8): reads expenses from a
/// typed or spoken phrase with fixed rules, in French, English and Darija in
/// Latin letters. "coffee 3.5 and taxi 8", "3.5 café w 8 taxi",
/// "kaskrout b 3500".
///
/// - **Items** are split at "and", "et", "w", "wa", "o", "puis", "+", "," and
///   ";". With no separator, each amount takes the words on its label side:
///   before it if the phrase starts with a label, after it if it starts
///   with an amount.
/// - **Amounts:** "3.5", "3,5", "4,500" (a lone separator is the decimal
///   point), with an optional unit: "3dt", "3 dinars", "500 millimes",
///   "3d500", "3 dinars w 500 millimes", "€4". In TND a bare whole number of
///   1000 or more is millimes, as students say prices ("kaskrout 3500" is
///   3.500 DT).
/// - **Labels** are the remaining words, without fillers at their ends
///   ("j'ai payé", "for", "b", "khallast").
/// - **Confidence** (0-100) drops for: no label, a label with no known
///   word ([ExpenseKeywords]), a millime guess, words merged into an item,
///   and a unit in another currency. Numbers in words ("trois", "khamsa")
///   or words left without an amount mark the input as missed. Below
///   [fallbackBelow], the LLM tier (task 5.5) should try.
///
/// Nothing parsed is saved before the user confirms it.
class ParseExpenseText {
  const ParseExpenseText();

  /// Inputs less sure than this go to the LLM fallback.
  static const fallbackBelow = 60;

  static const _noLabel = 45;
  static const _unknownLabel = 15;
  static const _millimeGuess = 10;
  static const _merged = 25;
  static const _otherCurrency = 50;

  ParsedInput call(String text, {required Currency currency}) {
    final tokens = _combineDinarsAndMillimes(_tokenize(text, currency));
    final amountFirst =
        tokens.firstWhere(
              (t) => t is! _Sep && !(t is _Word && t.isFiller),
              orElse: () => const _Sep(),
            )
            is _Amount;

    var missed = tokens.any((t) => t is _Word && t.isNumberWord);
    final items = <_Draft>[];
    var pending = <_Word>[];
    for (final segment in _segments(tokens)) {
      final drafts = _readSegment(segment, amountFirst: amountFirst);
      if (drafts.isEmpty) {
        pending.addAll(segment.whereType<_Word>());
        continue;
      }
      if (_trim(pending).isNotEmpty) {
        drafts.first
          ..words.insertAll(0, [...pending, _Word.joiner])
          ..penalty += _merged;
      }
      pending = [];
      items.addAll(drafts);
    }
    if (_trim(pending).isNotEmpty) {
      if (items.isEmpty) {
        missed = true;
      } else {
        items.last
          ..words.addAll([_Word.joiner, ...pending])
          ..penalty += _merged;
      }
    }

    // An amount that couldn't be read ("3.5 millimes") is 0: dropped.
    final read = [
      for (final draft in items)
        if (draft.amount.amount.isPositive) draft.toItem(),
    ];
    return ParsedInput(
      items: read,
      missedSomething: missed || read.length < items.length,
    );
  }

  /// Each segment's items. Empty if it holds no amount.
  static List<_Draft> _readSegment(
    List<_Token> segment, {
    required bool amountFirst,
  }) {
    final amounts = segment.whereType<_Amount>().toList();
    if (amounts.isEmpty) return [];
    if (amounts.length == 1) {
      return [_Draft(amounts.single, segment.whereType<_Word>().toList())];
    }

    // Several amounts with no separator: split at them.
    final drafts = [for (final a in amounts) _Draft(a, [])];
    var index = amountFirst ? -1 : 0;
    final stray = <_Word>[];
    for (final token in segment) {
      switch (token) {
        case _Amount():
          index++;
        case _Word() when index < 0 || index >= drafts.length:
          stray.add(token);
        case _Word():
          drafts[index].words.add(token);
        case _Sep():
      }
    }
    if (_trim(stray).isNotEmpty) {
      final into = amountFirst ? drafts.first : drafts.last;
      if (amountFirst) {
        into.words.insertAll(0, stray);
      } else {
        into.words.addAll(stray);
      }
      into.penalty += _merged;
    }
    return drafts;
  }

  /// The tokens between separators, without empty ones.
  static List<List<_Token>> _segments(List<_Token> tokens) {
    final segments = <List<_Token>>[[]];
    for (final token in tokens) {
      if (token is _Sep) {
        segments.add([]);
      } else {
        segments.last.add(token);
      }
    }
    return [
      for (final s in segments)
        if (s.isNotEmpty) s,
    ];
  }

  /// [words] without fillers at either end.
  static List<_Word> _trim(List<_Word> words) {
    var start = 0;
    var end = words.length;
    while (start < end && words[start].isFiller) {
      start++;
    }
    while (end > start && words[end - 1].isFiller) {
      end--;
    }
    return words.sublist(start, end);
  }

  // --- Tokens ---------------------------------------------------------------

  static final _number = RegExp(r'^\d+(?:[.,]\d+)?$');
  static final _numberWithUnit = RegExp(r'^(\d+(?:[.,]\d+)?)([^\d.,]+)$');
  static final _unitThenNumber = RegExp(r'^([€$])(\d+(?:[.,]\d+)?)$');
  static final _compactDinars = RegExp(r'^(\d+)d(\d{1,3})$');
  static final _elision = RegExp(r"^(?:l|d|j|qu|m|t|s|n|c)'(.+)$");
  static final _leading = RegExp(r'''^["'«(\[]+''');
  static final _trailing = RegExp(r'''["'»)\].!?:]+$''');

  static List<_Token> _tokenize(String text, Currency currency) {
    final tokens = <_Token>[];
    for (var raw in text.replaceAll('’', "'").split(RegExp(r'\s+'))) {
      raw = raw.replaceFirst(_leading, '');
      var sepAfter = false;
      while (raw.endsWith(',') || raw.endsWith(';')) {
        raw = raw.substring(0, raw.length - 1);
        sepAfter = true;
      }
      raw = raw.replaceFirst(_trailing, '');
      if (raw.isNotEmpty) _addToken(tokens, raw, currency);
      if (sepAfter) tokens.add(const _Sep());
    }
    return tokens;
  }

  static void _addToken(List<_Token> tokens, String raw, Currency currency) {
    final key = ExpenseKeywords.normalize(raw);
    if (_separators.contains(key)) {
      tokens.add(const _Sep());
      return;
    }

    final unit = _units[key];
    if (unit != null) {
      // "3 dt": the unit of the amount before it; otherwise a filler.
      final last = tokens.isEmpty ? null : tokens.last;
      if (last is _Amount && last.unit == _Unit.none) {
        tokens[tokens.length - 1] = _Amount.read(last.number, unit, currency);
      }
      return;
    }

    if (_number.hasMatch(key)) {
      tokens.add(_Amount.read(key, _Unit.none, currency));
      return;
    }
    if (_compactDinars.firstMatch(key) case final m?) {
      tokens.add(
        _Amount.read('${m[1]}.${m[2]!.padLeft(3, '0')}', _Unit.major, currency),
      );
      return;
    }
    final withUnit = _numberWithUnit.firstMatch(key);
    final unitFirst = _unitThenNumber.firstMatch(key);
    final (numberText, unitText) = withUnit != null
        ? (withUnit[1]!, withUnit[2]!)
        : unitFirst != null
        ? (unitFirst[2]!, unitFirst[1]!)
        : (null, null);
    if (numberText != null && _units[unitText] != null) {
      tokens.add(_Amount.read(numberText, _units[unitText]!, currency));
      return;
    }

    final word = _elision.firstMatch(raw)?[1] ?? raw;
    tokens.add(_Word(word));
  }

  /// "3 dinars w 500 millimes", "3 dinars 500" → one amount.
  static List<_Token> _combineDinarsAndMillimes(List<_Token> tokens) {
    final out = <_Token>[];
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token is _Amount && token.unit == _Unit.major && token.isWhole) {
        final next = i + 1 < tokens.length ? tokens[i + 1] : null;
        final afterSep = i + 2 < tokens.length ? tokens[i + 2] : null;
        final (millimes, skip) = switch ((next, afterSep)) {
          (_Amount n, _) when n.isMillimePart(explicit: false) => (n, 1),
          (_Sep(), _Amount n) when n.isMillimePart(explicit: true) => (n, 2),
          _ => (null, 0),
        };
        if (millimes != null && token.amount.currency == Currency.tnd) {
          out.add(token.plusMillimes(millimes));
          i += skip;
          continue;
        }
      }
      out.add(token);
    }
    return out;
  }

  static const _separators = {
    'and',
    'et',
    'w',
    'wa',
    'o',
    'puis',
    'then',
    'plus',
    'ensuite',
    'ba3d',
    '+',
    '&',
    ',',
    ';',
  };

  static const _units = {
    'dt': _Unit.major,
    'tnd': _Unit.major,
    'd': _Unit.major,
    'dinar': _Unit.major,
    'dinars': _Unit.major,
    'din': _Unit.major,
    'millimes': _Unit.minor,
    'millime': _Unit.minor,
    'mil': _Unit.minor,
    'mill': _Unit.minor,
    'm': _Unit.minor,
    'eur': _Unit.eur,
    'euro': _Unit.eur,
    'euros': _Unit.eur,
    '€': _Unit.eur,
    'usd': _Unit.usd,
    'dollar': _Unit.usd,
    'dollars': _Unit.usd,
    r'$': _Unit.usd,
  };
}

enum _Unit { none, major, minor, eur, usd }

sealed class _Token {
  const _Token();
}

class _Sep extends _Token {
  const _Sep();
}

class _Word extends _Token {
  _Word(this.text) : key = ExpenseKeywords.normalize(text);

  /// Stands for a separator inside a merged label.
  static final joiner = _Word('+');

  final String text;
  final String key;

  bool get isFiller =>
      _fillers.contains(text.toLowerCase()) || identical(this, joiner);

  bool get isNumberWord => _numberWords.contains(key);

  bool get isKnown => ExpenseKeywords.categoryOf(key) != null;

  /// Words with no meaning for the expense, trimmed from label ends. Matched
  /// with accents, so "thé" (tea) isn't "the".
  static const _fillers = {
    // English.
    'i', "i've", 'spent', 'paid', 'pay', 'bought', 'buy', 'for', 'on', 'at',
    'a', 'an', 'the', 'my', 'of', 'some', 'today', 'yesterday', 'cost',
    'costs', 'it', 'was',
    // French.
    'ai', 'payé', 'paye', 'dépensé', 'depense', 'acheté', 'achete', 'pour',
    'un', 'une', 'le', 'la', 'les', 'du', 'des', 'de', 'à', 'au', 'aux',
    'en', 'mon', 'ma', 'mes', 'sur', 'aujourd\'hui', 'hier', 'coûte',
    'coute', 'fait',
    // Darija.
    'b', 'bi', 'fi', '3la', 'ala', 'el', 'l', 'khallast', 'khalast',
    'khlast', '5allast', '5alast', 'chrit', 'chrite', 'lyoum', 'lbera7',
    'bel', 'mta3',
  };

  /// Numbers said as words: the rules don't read them.
  static const _numberWords = {
    'deux',
    'trois',
    'quatre',
    'cinq',
    'sept',
    'huit',
    'neuf',
    'dix',
    'onze',
    'douze',
    'quinze',
    'vingt',
    'trente',
    'quarante',
    'cinquante',
    'cent',
    'mille',
    'demi',
    'two',
    'three',
    'four',
    'five',
    'seven',
    'eight',
    'nine',
    'ten',
    'twenty',
    'thirty',
    'fifty',
    'hundred',
    'thousand',
    'half',
    'wa7ed',
    'wahed',
    'zouz',
    'thletha',
    'tletha',
    'arb3a',
    'arba',
    'khamsa',
    '5amsa',
    'setta',
    'sab3a',
    'thmenya',
    'tes3a',
    '3achra',
    'achra',
    'mya',
    'mitin',
    'alf',
    'alfin',
    'nos',
    'noss',
    'rbo3',
  };
}

class _Amount extends _Token {
  const _Amount(
    this.number,
    this.unit,
    this.amount, {
    this.millimeGuess = false,
    this.otherCurrency = false,
  });

  /// [number] read in [currency] with [unit]. An amount it can't read
  /// (too many decimals, "3.5 millimes") is 0, which drops the item.
  factory _Amount.read(String number, _Unit unit, Currency currency) {
    final whole = !number.contains('.') && !number.contains(',');
    final otherCurrency = switch (unit) {
      _Unit.eur => currency != Currency.eur,
      _Unit.usd => currency != Currency.usd,
      _Unit.major || _Unit.minor => currency != Currency.tnd,
      _Unit.none => false,
    };
    final millimes =
        currency == Currency.tnd &&
        whole &&
        (unit == _Unit.minor ||
            (unit == _Unit.none && int.parse(number) >= 1000));
    final Money amount;
    if (millimes) {
      amount = Money(int.parse(number), currency);
    } else if (unit == _Unit.minor) {
      amount = Money.zero(currency);
    } else {
      amount = switch (const MoneyParser().parse(number, currency: currency)) {
        Ok(:final value) => value,
        Err() => Money.zero(currency),
      };
    }
    return _Amount(
      number,
      unit,
      amount,
      millimeGuess: millimes && unit == _Unit.none,
      otherCurrency: otherCurrency,
    );
  }

  final String number;
  final _Unit unit;
  final Money amount;
  final bool millimeGuess;
  final bool otherCurrency;

  bool get isWhole => !number.contains('.') && !number.contains(',');

  /// The "500" of "3 dinars 500" (3 digits) or of "3 dinars w 500
  /// millimes" ([explicit]: the unit is needed after a separator).
  bool isMillimePart({required bool explicit}) =>
      isWhole &&
      int.parse(number) < 1000 &&
      (unit == _Unit.minor ||
          (!explicit && unit == _Unit.none && number.length == 3));

  _Amount plusMillimes(_Amount millimes) => _Amount(
    number,
    unit,
    amount + Money(int.parse(millimes.number), amount.currency),
  );
}

class _Draft {
  _Draft(this.amount, this.words);

  final _Amount amount;
  final List<_Word> words;
  var penalty = 0;

  ParsedItem toItem() {
    final label = ParseExpenseText._trim(words);
    final known = label.any((w) => w.isKnown);
    var confidence = 100 - penalty;
    if (label.isEmpty) {
      confidence -= ParseExpenseText._noLabel;
    } else if (!known) {
      confidence -= ParseExpenseText._unknownLabel;
    }
    if (amount.millimeGuess) confidence -= ParseExpenseText._millimeGuess;
    if (amount.otherCurrency) confidence -= ParseExpenseText._otherCurrency;
    return ParsedItem(
      label: label
          .map((w) => identical(w, _Word.joiner) ? '+' : w.text)
          .join(' '),
      amount: amount.amount,
      confidence: confidence.clamp(0, 100),
    );
  }
}
