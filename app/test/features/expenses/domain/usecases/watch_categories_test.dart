import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/usecases/watch_categories.dart';
import 'package:test/test.dart';

import '../../../../support/fake_category_repository.dart';

void main() {
  test('passes the repository categories through', () async {
    final watch = WatchCategories(FakeCategoryRepository());

    expect((await watch().first).valueOrNull, DefaultCategories.all);
  });

  test('the defaults are the student categories, with unique ids', () {
    expect(DefaultCategories.all.map((c) => c.id), [
      'food',
      'transport',
      'rent',
      'study',
      'leisure',
      'other',
    ]);
    expect(DefaultCategories.all.every((c) => !c.archived), isTrue);
  });
}
