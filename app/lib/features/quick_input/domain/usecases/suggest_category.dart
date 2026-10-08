import '../../../expenses/domain/entities/category.dart';
import '../value_objects/expense_keywords.dart';

/// A first category guess for a quick-input item, from the keyword list:
/// the keyword's category if it is active, else null (the user picks).
/// The categorizer (task 5.7) adds the user's own corrections and the LLM.
class SuggestCategory {
  const SuggestCategory();

  String? call(String label, {required List<Category> categories}) {
    final id = ExpenseKeywords.categoryOf(label);
    if (id == null) return null;
    final active = categories.any((c) => c.id == id && !c.archived);
    return active ? id : null;
  }
}
