import 'dart:async';
import 'dart:convert';

import '../../../../core/result/result.dart';
import '../../../expenses/domain/entities/category.dart';
import '../repositories/expense_llm.dart';
import '../value_objects/category_source.dart';
import '../value_objects/category_suggestion.dart';
import '../value_objects/quick_input_failure.dart';

/// The categorizer's last tier (ARCHITECTURE.md §8): asks the on-device
/// LLM to pick one of the user's active categories for a note, when memory
/// and keywords don't know it.
///
/// The answer must be JSON `{"category": "<name>"}` naming an active
/// category (case and spaces ignored); anything else, a failure, a
/// missing model or [timeout] gives null, and the user picks.
class AskLlmCategory {
  const AskLlmCategory(this._llm, {this.timeout = const Duration(seconds: 15)});

  final ExpenseLlm _llm;
  final Duration timeout;

  Future<CategorySuggestion?> call(
    String label, {
    required List<Category> categories,
  }) async {
    final note = label.trim();
    final active = [
      for (final c in categories)
        if (!c.archived) c,
    ];
    if (note.isEmpty || active.isEmpty || !await _llm.isInstalled()) {
      return null;
    }
    final answer = await _llm
        .complete(prompt(note, active))
        .then<Result<String, QuickInputFailure>>((answer) => answer)
        .timeout(timeout, onTimeout: () => const Ok(''));
    if (answer case Ok(:final value)) {
      final name = _name(value);
      for (final c in active) {
        if (name != null && _same(c.name, name)) {
          return CategorySuggestion(
            categoryId: c.id,
            source: CategorySource.llm,
          );
        }
      }
    }
    return null;
  }

  static String prompt(String note, List<Category> categories) =>
      '''
Pick the category of a student's expense. Answer with JSON only: {"category":"<one of the names>"}
Categories: ${categories.map((c) => c.name).join(', ')}
Expense: "$note"
''';

  static String? _name(String answer) {
    final start = answer.indexOf('{');
    final end = answer.lastIndexOf('}');
    if (start < 0 || end < start) return null;
    try {
      final json = jsonDecode(answer.substring(start, end + 1));
      return json is Map<String, Object?> && json['category'] is String
          ? json['category']! as String
          : null;
    } on FormatException {
      return null;
    }
  }

  static bool _same(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
