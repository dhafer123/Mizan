import '../../../expenses/domain/entities/default_categories.dart';

/// Words students use for what they buy, in French, English and Tunisian
/// Darija in Latin letters (digits as letters: 9 = ق, 3 = ع, 7 = ح,
/// 5 = خ), each with its default category.
///
/// The rule parser trusts a label more when it holds one of these; the
/// categorizer (task 5.7) uses them as its rules tier. Keys are lower case
/// without accents (see [normalize]).
abstract final class ExpenseKeywords {
  static const _food = DefaultCategories.food;
  static const _transport = DefaultCategories.transport;
  static const _rent = DefaultCategories.rent;
  static const _study = DefaultCategories.study;
  static const _leisure = DefaultCategories.leisure;
  static const _other = DefaultCategories.other;

  /// Word → default category id.
  static final Map<String, String> categories = Map.unmodifiable({
    for (final word in const [
      // Drinks and cafés.
      'cafe', 'coffee', 'kahwa', '9ahwa', 'kahoua', 'kahwet', 'express',
      'capucin', 'cappuccino', 'direct', 'tea', 'tay', 'chay', 'jus',
      'juice', 'eau', 'water', 'soda', 'coca', 'boisson', 'drink',
      // Meals.
      'lunch', 'dejeuner', 'diner', 'dinner', 'breakfast', 'ftour', 'f6our',
      '3cha', 'acha', 'meal', 'repas', 'resto', 'restaurant', 'snack',
      'sandwich', 'kaskrout', 'kaskroute', 'chapati', 'mlewi', 'lablebi',
      'makloub', 'pizza', 'burger', 'tacos', 'brik', 'msemen', 'chawarma',
      'shawarma', 'couscous', 'ojja', 'food', 'makla',
      // Shopping for food.
      'pain', 'bread', 'khobz', '5obz', 'croissant', 'bambalouni',
      'gateau', 'cake', 'glace', 'chocolat', 'lait', 'milk', 'yaourt',
      'fruits', 'khodhra', 'legumes', 'courses', 'groceries', 'epicerie',
      'hanout', '7anout', 'marche', 'souk', 'monoprix', 'carrefour',
      'aziza', 'magasin',
    ])
      word: _food.id,
    for (final word in const [
      'taxi',
      'louage',
      'metro',
      'bus',
      'kar',
      'train',
      'tgm',
      'essence',
      'fuel',
      'benzine',
      'carburant',
      'uber',
      'bolt',
      'indrive',
      'parking',
      'transport',
      'ticket',
    ])
      word: _transport.id,
    for (final word in const [
      'rent',
      'loyer',
      'kra',
      'kira',
      'chambre',
      'foyer',
      'steg',
      'sonede',
      'electricite',
      'electricity',
    ])
      word: _rent.id,
    for (final word in const [
      'livre',
      'livres',
      'book',
      'books',
      'kteb',
      'ktob',
      'photocopie',
      'photocopies',
      'copie',
      'copies',
      'impression',
      'print',
      'printing',
      'cahier',
      'notebook',
      'stylo',
      'pen',
      'inscription',
      'fees',
      'cours',
      'formation',
      'fac',
      'universite',
      'study',
    ])
      word: _study.id,
    for (final word in const [
      'cinema',
      'film',
      'movie',
      'netflix',
      'spotify',
      'chicha',
      'shisha',
      'match',
      'foot',
      'sortie',
      'outing',
      'concert',
      'jeu',
      'game',
      'games',
      'gym',
      'sport',
      'plage',
      'beach',
      'voyage',
      'trip',
      'fete',
      'party',
    ])
      word: _leisure.id,
    for (final word in const [
      'recharge',
      'flexy',
      'forfait',
      'telephone',
      'phone',
      'internet',
      'wifi',
      'pharmacie',
      'pharmacy',
      'dwa',
      'dwe',
      'medicaments',
      'medicine',
      'coiffeur',
      'hajjem',
      'haircut',
      'cadeau',
      'gift',
      'vetements',
      'clothes',
      'habits',
      'chaussures',
      'shoes',
      'savon',
      'shampoing',
    ])
      word: _other.id,
  });

  /// The category of the first known word in [label], or null.
  static String? categoryOf(String label) {
    for (final word in normalize(label).split(' ')) {
      final id = categories[word] ?? _plural(word);
      if (id != null) return id;
    }
    return null;
  }

  static String? _plural(String word) => word.length > 3 && word.endsWith('s')
      ? categories[word.substring(0, word.length - 1)]
      : null;

  /// Lower case, accents dropped ("Café" → "cafe"), apostrophes kept.
  static String normalize(String text) {
    final out = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      out.write(_plain[c] ?? c);
    }
    return out.toString();
  }

  static const _plain = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
    'œ': 'oe',
    'æ': 'ae',
    '’': "'",
  };
}
