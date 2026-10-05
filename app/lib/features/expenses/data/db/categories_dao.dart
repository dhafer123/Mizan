import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import '../../../sync/data/db/outbox_op_type.dart';
import '../../../sync/data/db/pending_op.dart';
import '../../../sync/data/db/sync_payload.dart';
import 'categories_table.dart';

part 'categories_dao.g.dart';

/// Stored categories: custom ones, and built-in defaults the user changed.
/// Every write also queues its sync op, in one transaction.
@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.attachedDatabase);

  static const entity = 'categories';

  Future<CategoryRow?> findById(String id) =>
      (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Live (not deleted) categories, archived ones included.
  Stream<List<CategoryRow>> watchLive() => _live().watch();

  /// [watchLive], read once.
  Future<List<CategoryRow>> getLive() => _live().get();

  SimpleSelectStatement<$CategoriesTable, CategoryRow> _live() =>
      select(categories)..where((c) => c.deleted.not());

  Future<void> insertCategory(CategoryRow row) =>
      attachedDatabase.outboxDao.recordWrite(
        PendingOp(
          entity: entity,
          entityId: row.id,
          type: OutboxOpType.create,
          changedFields: syncPayload(row),
          baseVersion: row.version,
        ),
        () => into(categories).insert(row),
      );

  /// Saves [updated] and queues only the fields that changed. Sync metadata
  /// in [updated] is ignored. Returns false if nothing changed.
  ///
  /// If no row has this id yet, [builtIn] is the built-in default it
  /// overrides: the row is stored and queued as an *update* of that default,
  /// which every device and the server hold implicitly at version 0 (see
  /// docs/decisions/0001-built-in-default-categories.md).
  ///
  /// Throws [StateError] if there is neither a live row nor a [builtIn].
  Future<bool> updateCategory(CategoryRow updated, {CategoryRow? builtIn}) =>
      transaction(() async {
        final stored = await findById(updated.id);
        final current = stored != null && !stored.deleted ? stored : builtIn;
        if (current == null) {
          throw StateError('No live category with id ${updated.id}');
        }
        final changed = changedSyncFields(current, updated);
        if (changed.isEmpty) return false;

        final row = updated.copyWith(
          version: current.version,
          deleted: false,
          updatedBy: Value(current.updatedBy),
          serverSeq: Value(current.serverSeq),
        );
        await attachedDatabase.outboxDao.recordWrite(
          PendingOp(
            entity: entity,
            entityId: current.id,
            type: OutboxOpType.update,
            changedFields: changed,
            baseVersion: current.version,
          ),
          () => stored == null
              ? into(categories).insert(row)
              : update(categories).replace(row),
        );
        return true;
      });
}
