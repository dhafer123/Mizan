import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/usecases/archive_category.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_error.dart';
import 'package:test/test.dart';

import '../../../../support/fake_category_repository.dart';

void main() {
  late FakeCategoryRepository repository;
  late ArchiveCategory archiveCategory;

  setUp(() {
    repository = FakeCategoryRepository();
    archiveCategory = ArchiveCategory(repository);
  });

  test('archives the category and keeps everything else', () async {
    final result = await archiveCategory('food');

    final expected = DefaultCategories.food.copyWith(archived: true);
    expect(result.valueOrNull, expected);
    expect(repository.byId('food'), expected);
  });

  test('archiving twice changes nothing', () async {
    await archiveCategory('food');
    await archiveCategory('food');

    expect(repository.updates, hasLength(1));
  });

  test('the last active category stays', () async {
    for (final category in DefaultCategories.all.skip(1)) {
      expect((await archiveCategory(category.id)).isOk, isTrue);
    }

    final result = await archiveCategory('food');

    expect(result.failureOrNull?.error, CategoryError.lastActive);
    expect(repository.byId('food').archived, isFalse);
  });

  test('a custom category counts as active', () async {
    repository.categories
      ..clear()
      ..addAll([
        DefaultCategories.food,
        const Category(id: 'c1', name: 'Gym', icon: 'sport'),
      ]);

    expect((await archiveCategory('food')).isOk, isTrue);
    expect(
      (await archiveCategory('c1')).failureOrNull?.error,
      CategoryError.lastActive,
    );
  });

  test('fails for an unknown id', () async {
    final result = await archiveCategory('nope');
    expect(result.failureOrNull?.error, CategoryError.notFound);
  });
}
