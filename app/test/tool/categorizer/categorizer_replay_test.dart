import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';

import '../../../tool/categorizer/categorizer_replay.dart';

List<Expense> _history(List<(String, String)> notes) => [
  for (final (i, (note, category)) in notes.indexed)
    Expense(
      id: 'e${i.toString().padLeft(3, '0')}',
      amount: const Money(1000, Currency.tnd),
      categoryId: category,
      date: DateTime.utc(2026, 9, 1).add(Duration(days: i ~/ 3)),
      note: note,
    ),
];

/// A synthetic month of a student's notes, in order, with the category
/// they chose: keywords, shops met for the first time, shops seen again,
/// and a café the student files under leisure. Written by the developer
/// alongside the rules, so it is a regression set, not a held-out one.
const _month = [
  ('kahwa', 'food'),
  ('taxi', 'transport'),
  ('Café Le Baron', 'leisure'),
  ('Monoprix Menzah', 'food'),
  ('louage Sousse', 'transport'),
  ('Chez Salah', 'food'),
  ('photocopies', 'study'),
  ('Café Le Baron', 'leisure'),
  ('Librairie Al Kitab', 'study'),
  ('kaskrout', 'food'),
  ('Pharmacie Ennasr', 'other'),
  ('Chez Salah', 'food'),
  ('metro', 'transport'),
  ('recharge Ooredoo', 'other'),
  ('California Gym', 'leisure'),
  ('Baron', 'leisure'),
  ('loyer', 'rent'),
  ('STEG', 'rent'),
  ('Librairie Al Kitab', 'study'),
  ('netflix', 'leisure'),
  ('jus', 'food'),
  ('Ooredoo', 'other'),
  ('Chez Salah', 'food'),
  ('bus', 'transport'),
  ('Zara', 'other'),
  ('cinema', 'leisure'),
  ('Zara', 'other'),
  ('kra', 'rent'),
  ('Café Le Baron', 'leisure'),
  ('lablebi', 'food'),
  ('Uber', 'transport'),
  ('Pharmacie Ennasr', 'other'),
  ('Dar Chaabane', 'food'),
  ('cahier', 'study'),
  ('Dar Chaabane', 'food'),
  ('Bolt', 'transport'),
  ('sortie', 'leisure'),
  ('Baron', 'leisure'),
  ('yaourt', 'food'),
  ('Tunisie Telecom', 'other'),
  ('fac inscription', 'study'),
  ('Tunisie Telecom', 'other'),
  ('pizza', 'food'),
  ('coiffeur', 'other'),
  ('louage', 'transport'),
  ('match foot', 'leisure'),
  ('Chez Salah', 'food'),
  ('Magasin General', 'food'),
  ('tickets metro', 'transport'),
  ('Librairie Al Kitab', 'study'),
  ('Dar Chaabane', 'food'),
  ('parking', 'transport'),
  ('shampoing', 'other'),
  ('Baron', 'leisure'),
  ('khobz', 'food'),
  ('cadeau anniversaire', 'other'),
  ('Zara', 'other'),
  ('kahwa', 'food'),
  ('Ooredoo', 'other'),
  ('essence', 'transport'),
];

void main() {
  test('each expense only learns from the ones before it', () {
    final replay = CategorizerReplay.of(
      _history(const [
        ('Café Le Baron', 'leisure'),
        ('Café Le Baron', 'leisure'),
        ('zorblax', 'other'),
      ]),
      categories: DefaultCategories.all,
    );
    expect(replay.total, 3);
    // Keywords say food for the café both times.
    expect(replay.rulesRight, 0);
    // The second café learns from the first; zorblax is new.
    expect(replay.memoryRight, 1);
    expect(replay.memorySuggested, 2);
  });

  test('expenses without a note are skipped', () {
    final history = _history(const [('kahwa', 'food')]);
    final replay = CategorizerReplay.of([
      ...history,
      history.first.copyWith(id: 'x', note: null),
    ], categories: DefaultCategories.all);
    expect(replay.total, 1);
  });

  test('categorization accuracy on a synthetic month (METRICS.md)', () {
    expect(_month.length, 60);
    final replay = CategorizerReplay.of(
      _history(_month),
      categories: DefaultCategories.all,
    );
    // ignore: avoid_print
    print('Categorizer: $replay');
    expect(replay.memoryRight, greaterThanOrEqualTo(replay.rulesRight));
  });
}
