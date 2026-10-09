import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/quick_input/domain/usecases/learn_categories.dart';
import 'package:mizan/features/quick_input/domain/usecases/suggest_category.dart';
import 'package:mizan/features/quick_input/domain/value_objects/category_memory.dart';

/// How often the categorizer's fast tiers would have suggested the category
/// the user really chose, replaying expenses in order: each one is
/// suggested from the expenses before it only (task 5.7, METRICS.md).
class CategorizerReplay {
  const CategorizerReplay({
    required this.total,
    required this.rulesRight,
    required this.memoryRight,
    required this.memorySuggested,
  });

  /// Replays the [expenses] with a note, oldest first.
  factory CategorizerReplay.of(
    List<Expense> expenses, {
    required List<Category> categories,
  }) {
    const suggest = SuggestCategory();
    const learn = LearnCategories();
    final sorted =
        [
          for (final e in expenses)
            if (e.note?.trim().isNotEmpty ?? false) e,
        ]..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });

    var rulesRight = 0;
    var memoryRight = 0;
    var memorySuggested = 0;
    for (var i = 0; i < sorted.length; i++) {
      final e = sorted[i];
      final rules = suggest(e.note!, categories: categories);
      final withMemory = suggest(
        e.note!,
        categories: categories,
        memory: i == 0 ? CategoryMemory.empty : learn(sorted.sublist(0, i)),
      );
      if (rules?.categoryId == e.categoryId) rulesRight++;
      if (withMemory?.categoryId == e.categoryId) memoryRight++;
      if (withMemory != null) memorySuggested++;
    }
    return CategorizerReplay(
      total: sorted.length,
      rulesRight: rulesRight,
      memoryRight: memoryRight,
      memorySuggested: memorySuggested,
    );
  }

  /// Expenses with a note, replayed.
  final int total;

  /// Right with keywords only.
  final int rulesRight;

  /// Right with memory, then keywords.
  final int memoryRight;

  /// Given any suggestion with memory, then keywords.
  final int memorySuggested;

  @override
  String toString() {
    String pct(int n) =>
        total == 0 ? '-' : '${(n * 1000 / total).round() / 10}%';
    return '$total expenses with a note: keywords only $rulesRight '
        '(${pct(rulesRight)}), memory + keywords $memoryRight '
        '(${pct(memoryRight)}); a suggestion for $memorySuggested '
        '(${pct(memorySuggested)})';
  }
}
