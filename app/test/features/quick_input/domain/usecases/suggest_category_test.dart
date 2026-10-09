import 'dart:math';

import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/quick_input/domain/usecases/learn_categories.dart';
import 'package:mizan/features/quick_input/domain/usecases/suggest_category.dart';
import 'package:mizan/features/quick_input/domain/value_objects/category_memory.dart';
import 'package:mizan/features/quick_input/domain/value_objects/category_source.dart';
import 'package:mizan/features/quick_input/domain/value_objects/category_suggestion.dart';

const _suggest = SuggestCategory();
const _learn = LearnCategories();
const _all = DefaultCategories.all;

var _ids = 0;

Expense _spent(String note, String category, {int day = 1}) => Expense(
  id: 'e${(_ids++).toString().padLeft(6, '0')}',
  amount: const Money(1000, Currency.tnd),
  categoryId: category,
  date: DateTime.utc(2026, 10, day),
  note: note,
);

CategorySuggestion? _for(String label, [List<Expense> history = const []]) =>
    _suggest(label, categories: _all, memory: _learn(history));

void main() {
  test('one correction changes the next suggestion for the same shop '
      '(Done when, task 5.7)', () {
    // Keywords alone: a café is food.
    expect(
      _for('Café Le Baron'),
      const CategorySuggestion(
        categoryId: 'food',
        source: CategorySource.rules,
      ),
    );

    // The user files it under leisure once (they go there to play cards).
    final history = [_spent('Café Le Baron', 'leisure', day: 2)];

    expect(
      _for('Café Le Baron', history),
      const CategorySuggestion(
        categoryId: 'leisure',
        source: CategorySource.memory,
      ),
    );
    // Written differently, still the same shop.
    expect(_for('  café le BARON! ', history)?.categoryId, 'leisure');
    // Other cafés are still food.
    expect(_for('café', history)?.categoryId, 'food');
  });

  test('the most recent choice wins', () {
    final history = [
      _spent('Baron', 'food', day: 1),
      _spent('Baron', 'leisure', day: 3),
      _spent('Baron', 'other', day: 2),
    ];
    expect(_for('Baron', history)?.categoryId, 'leisure');
  });

  test('a known word of a new note: its most recent category', () {
    final history = [
      _spent('Baron coffee', 'leisure', day: 1),
      _spent('Chez Salah', 'food', day: 2),
    ];
    // "baron" was last seen on day 1, "salah" on day 2.
    expect(
      _for('Baron', history),
      const CategorySuggestion(
        categoryId: 'leisure',
        source: CategorySource.memory,
      ),
    );
    expect(_for('Baron Salah', history)?.categoryId, 'food');
  });

  test('filler and keyword words teach nothing; distinctive ones do', () {
    final history = [_spent('pour le bus Salah', 'other')];
    // "pour", "le" and "bus" (a keyword) aren't learned; "salah" is.
    expect(_for('pour la pizza', history)?.categoryId, 'food');
    expect(_for('bus 23', history)?.categoryId, 'transport');
    expect(_for('Salah 23', history)?.categoryId, 'other');
  });

  test('an archived category is never suggested; the next tier is', () {
    final archived = [
      for (final c in _all) c.id == 'leisure' ? c.copyWith(archived: true) : c,
    ];
    final memory = _learn([_spent('kahwa', 'leisure')]);
    expect(
      _suggest('kahwa', categories: archived, memory: memory),
      const CategorySuggestion(
        categoryId: 'food',
        source: CategorySource.rules,
      ),
    );
  });

  test('a custom category is learned like any other', () {
    final gym = [
      ..._all,
      const Category(id: 'gym', name: 'Gym', icon: 'other'),
    ];
    final memory = _learn([_spent('California Gym', 'gym')]);
    expect(
      _suggest('california gym', categories: gym, memory: memory)?.categoryId,
      'gym',
    );
  });

  test('nothing known: no suggestion', () {
    expect(_for('zorblax'), isNull);
    expect(_for(''), isNull);
    expect(_for('   '), isNull);
  });

  group('properties', () {
    Glados(any.categoryHistory, ExploreConfig(numRuns: 500)).test(
      "a note's suggestion is the category of its latest expense",
      (history) {
        final memory = _learn(history);
        for (final e in history) {
          final latest = history
              .where(
                (h) =>
                    LearnCategories.noteKey(h.note!) ==
                    LearnCategories.noteKey(e.note!),
              )
              .reduce((a, b) {
                final byDate = a.date.compareTo(b.date);
                final later = byDate != 0
                    ? byDate > 0
                    : a.id.compareTo(b.id) > 0;
                return later ? a : b;
              });
          expect(
            _suggest(e.note!, categories: _all, memory: memory)?.categoryId,
            latest.categoryId,
          );
        }
      },
    );

    Glados(any.categoryHistory).test('an empty memory changes nothing', (
      history,
    ) {
      for (final e in history) {
        expect(
          _suggest(e.note!, categories: _all, memory: CategoryMemory.empty),
          _suggest(e.note!, categories: _all),
        );
      }
    });
  });
}

extension _CategorizerAnys on Any {
  /// Up to 30 expenses with notes from a small pool (so they repeat), random
  /// days and categories.
  Generator<List<Expense>> get categoryHistory =>
      combine2(intInRange(0, 30), intInRange(0, 1 << 32), (int n, int seed) {
        final random = Random(seed);
        const notes = [
          'Baron',
          'café baron',
          'Monoprix',
          'kahwa',
          'louage',
          'zorblax shop',
          'Gym 6',
          'livre',
        ];
        final ids = [for (final c in _all) c.id];
        return [
          for (var i = 0; i < n; i++)
            Expense(
              id: 'p${i.toString().padLeft(3, '0')}',
              amount: const Money(1000, Currency.tnd),
              categoryId: ids[random.nextInt(ids.length)],
              date: DateTime.utc(2026, 9, 1 + random.nextInt(28)),
              note: notes[random.nextInt(notes.length)],
            ),
        ];
      });
}
