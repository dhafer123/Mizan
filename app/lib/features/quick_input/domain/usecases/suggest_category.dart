import '../../../expenses/domain/entities/category.dart';
import '../value_objects/category_memory.dart';
import '../value_objects/category_source.dart';
import '../value_objects/category_suggestion.dart';
import '../value_objects/expense_keywords.dart';
import 'learn_categories.dart';

/// The categorizer's fast tiers (ARCHITECTURE.md §8), for an expense's
/// note:
/// 1. the user's memory ([LearnCategories]): the same note, else the most
///    recently used of its words;
/// 2. the keyword list ([ExpenseKeywords]).
///
/// Only active categories are suggested. Null when neither knows; the LLM
/// tier (`AskLlmCategory`) can try then.
class SuggestCategory {
  const SuggestCategory();

  CategorySuggestion? call(
    String label, {
    required List<Category> categories,
    CategoryMemory memory = CategoryMemory.empty,
  }) {
    final active = {
      for (final c in categories)
        if (!c.archived) c.id,
    };
    CategorySuggestion? pick(String? id, CategorySource source) =>
        id != null && active.contains(id)
        ? CategorySuggestion(categoryId: id, source: source)
        : null;

    final key = LearnCategories.noteKey(label);
    if (key.isEmpty) return null;

    final exact = pick(memory.notes[key], CategorySource.memory);
    if (exact != null) return exact;

    (String, int)? latest;
    for (final word in LearnCategories.wordsOf(key)) {
      final seen = memory.words[word];
      if (seen == null || !active.contains(seen.$1)) continue;
      if (latest == null || seen.$2 > latest.$2) latest = seen;
    }
    if (latest != null) return pick(latest.$1, CategorySource.memory);

    return pick(ExpenseKeywords.categoryOf(label), CategorySource.rules);
  }
}
