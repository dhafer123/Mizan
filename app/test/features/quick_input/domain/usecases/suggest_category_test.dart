import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/quick_input/domain/usecases/suggest_category.dart';

void main() {
  const suggest = SuggestCategory();
  const all = DefaultCategories.all;

  test('a known word gives its category', () {
    expect(suggest('9ahwa', categories: all), 'food');
    expect(suggest('le louage', categories: all), 'transport');
    expect(suggest('Photocopies', categories: all), 'study');
  });

  test('an unknown word gives none', () {
    expect(suggest('zorblax', categories: all), isNull);
    expect(suggest('', categories: all), isNull);
  });

  test('an archived or missing category gives none', () {
    final archived = [
      for (final c in all) c.id == 'food' ? c.copyWith(archived: true) : c,
    ];
    expect(suggest('kahwa', categories: archived), isNull);
    expect(suggest('kahwa', categories: const []), isNull);
  });
}
