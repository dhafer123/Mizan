import 'dart:async';

import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/repositories/category_repository.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/category_failure.dart';

/// An in-memory [CategoryRepository] (the defaults unless given), for use
/// case and widget tests.
class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository([List<Category> categories = DefaultCategories.all])
    : categories = [...categories];

  /// In display order. Tests may change it before the first watch.
  final List<Category> categories;
  final _changes = StreamController<void>.broadcast();

  /// Every category passed to [update], in order.
  final updates = <Category>[];

  /// When set, [watchAll] emits this instead.
  CategoryFailure? failure;

  /// When set, every write fails with this.
  CategoryFailure? writeFailure;

  Category byId(String id) => categories.firstWhere((c) => c.id == id);

  @override
  Stream<Result<List<Category>, CategoryFailure>> watchAll() async* {
    yield _current();
    await for (final _ in _changes.stream) {
      yield _current();
    }
  }

  @override
  Future<Result<List<Category>, CategoryFailure>> getAll() async => _current();

  Result<List<Category>, CategoryFailure> _current() => switch (failure) {
    final failure? => Err(failure),
    null => Ok(List.unmodifiable(categories)),
  };

  @override
  Future<Result<void, CategoryFailure>> add(Category category) async {
    if (writeFailure case final failure?) return Err(failure);
    categories.add(category);
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void, CategoryFailure>> update(Category category) async {
    if (writeFailure case final failure?) return Err(failure);
    final index = categories.indexWhere((c) => c.id == category.id);
    if (index < 0) {
      return const Err(CategoryFailure(CategoryError.notFound));
    }
    categories[index] = category;
    updates.add(category);
    _changes.add(null);
    return const Ok(null);
  }
}
