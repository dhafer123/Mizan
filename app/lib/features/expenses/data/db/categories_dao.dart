import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import 'categories_table.dart';

part 'categories_dao.g.dart';

/// Stored categories: custom ones, and defaults the user changed (task 2.3).
@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.attachedDatabase);

  /// Live (not deleted) categories, archived ones included.
  Stream<List<CategoryRow>> watchLive() =>
      (select(categories)..where((c) => c.deleted.not())).watch();
}
