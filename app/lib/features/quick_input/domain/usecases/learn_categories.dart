import '../../../expenses/domain/entities/expense.dart';
import '../value_objects/category_memory.dart';
import '../value_objects/expense_keywords.dart';

/// Learns categories from the user's expenses (the categorizer's memory,
/// ARCHITECTURE.md §8). Every saved expense is a lesson, so correcting one
/// suggestion changes the next one for the same note: the most recent
/// expense wins (by date, then id, which is time-ordered).
///
/// Notes are compared lower case, without accents or punctuation. Words
/// are kept if they have 3+ letters and are distinctive: not filler
/// ("pour", "the") and not in the keyword list ("café", "taxi"), which
/// the rules already cover. So filing "Café Le Baron" under leisure
/// teaches "baron", not that every café is leisure.
class LearnCategories {
  const LearnCategories();

  CategoryMemory call(List<Expense> expenses) {
    final sorted =
        [
          for (final e in expenses)
            if (e.note?.trim().isNotEmpty ?? false) e,
        ]..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
    final notes = <String, String>{};
    final words = <String, (String, int)>{};
    for (final (rank, e) in sorted.indexed) {
      final key = noteKey(e.note!);
      if (key.isEmpty) continue;
      notes[key] = e.categoryId;
      for (final word in wordsOf(key)) {
        words[word] = (e.categoryId, rank);
      }
    }
    return CategoryMemory(notes: notes, words: words);
  }

  /// [note] lower case, without accents, punctuation or extra spaces.
  static String noteKey(String note) => ExpenseKeywords.normalize(note)
      .replaceAll(RegExp(r"[^\p{L}\p{N}']+", unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  /// The words of a [noteKey] worth remembering.
  static Iterable<String> wordsOf(String key) => key
      .split(' ')
      .where((w) => w.length >= 3 && !_filler.contains(w))
      .where((w) => ExpenseKeywords.categoryOf(w) == null)
      .where((w) => RegExp(r'\p{L}', unicode: true).hasMatch(w));

  static const _filler = {
    'the',
    'and',
    'for',
    'with',
    'from',
    'pour',
    'avec',
    'les',
    'des',
    'une',
    'dans',
    'sur',
    'chez',
    'par',
    'bel',
    'mta3',
    'fil',
    'ala',
  };
}
