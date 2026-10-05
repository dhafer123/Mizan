import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/expenses_providers.dart';
import '../../../../core/result/result.dart';
import '../../domain/value_objects/expense_failure.dart';

part 'pending_deletes.g.dart';

/// Swipe-to-delete with undo. A swiped expense is hidden at once but only
/// deleted when its undo window closes, so undo never has to un-delete
/// anything that may already have synced. If the app dies inside the window,
/// the expense simply stays.
///
/// Kept alive so a delete still commits after the list screen is closed.
@Riverpod(keepAlive: true)
class PendingDeletes extends _$PendingDeletes {
  @override
  Set<String> build() => const {};

  void hide(String id) => state = {...state, id};

  void undo(String id) => state = {...state}..remove(id);

  /// Deletes for real. On success the id stays hidden: the row is a
  /// tombstone now, and un-hiding it before the list re-reads would flash it
  /// back. On failure it shows again.
  Future<Result<void, ExpenseFailure>> commit(String id) async {
    final result = await ref.read(deleteExpenseProvider)(id);
    if (result.isErr) undo(id);
    return result;
  }
}
