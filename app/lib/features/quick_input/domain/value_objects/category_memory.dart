/// What the user's own expenses say about categories (`LearnCategories`):
/// for each note, and for each word in notes, the category of the most
/// recent expense with it. Computed from the expenses, never stored.
class CategoryMemory {
  const CategoryMemory({this.notes = const {}, this.words = const {}});

  static const empty = CategoryMemory();

  /// Normalized note → category id.
  final Map<String, String> notes;

  /// Normalized word → (category id, its rank: higher is more recent).
  final Map<String, (String, int)> words;
}
