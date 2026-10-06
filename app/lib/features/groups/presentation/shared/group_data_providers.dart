import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/groups_providers.dart';
import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../../../expenses/presentation/shared/no_retry.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/shared_expense.dart';
import '../../domain/value_objects/group_balances.dart';
import '../../domain/value_objects/group_invite.dart';
import '../../domain/value_objects/group_ledger.dart';
import '../../domain/value_objects/invite_preview.dart';
import '../../domain/value_objects/transfer.dart';

part 'group_data_providers.g.dart';

T _orThrow<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw failure,
};

/// Every group on this phone. A failure becomes the error state.
@Riverpod(retry: noRetry)
Stream<List<Group>> groups(Ref ref) =>
    ref.watch(watchGroupsProvider)().map(_orThrow);

/// One group; null once it's gone.
@Riverpod(retry: noRetry)
Stream<Group?> group(Ref ref, String id) =>
    ref.watch(watchGroupProvider)(id).map(_orThrow);

@Riverpod(retry: noRetry)
Stream<List<Member>> members(Ref ref, String groupId) =>
    ref.watch(watchMembersProvider)(groupId).map(_orThrow);

/// A group's expenses, newest first.
@Riverpod(retry: noRetry)
Stream<List<SharedExpense>> sharedExpenses(Ref ref, String groupId) =>
    ref.watch(watchSharedExpensesProvider)(groupId).map(_orThrow);

/// Every member's balance, recomputed whenever the group's rows change.
@Riverpod(retry: noRetry)
Stream<GroupBalances> groupBalances(Ref ref, String groupId) async* {
  final group = await ref.watch(groupProvider(groupId).future);
  final members = await ref.watch(membersProvider(groupId).future);
  if (group == null) return;
  yield* ref
      .watch(watchGroupBalancesProvider)(
        groupId,
        currency: group.currency,
        memberIds: {for (final m in members) m.id},
      )
      .map(_orThrow);
}

/// The group's expenses and payments.
@Riverpod(retry: noRetry)
Stream<GroupLedger> groupLedger(Ref ref, String groupId) =>
    ref.watch(watchGroupLedgerProvider)(groupId).map(_orThrow);

/// The fewest payments that settle everyone (`SimplifyDebts`), from the
/// current balances.
@Riverpod(retry: noRetry)
Future<List<Transfer>> suggestedTransfers(Ref ref, String groupId) async {
  final balances = await ref.watch(groupBalancesProvider(groupId).future);
  return _orThrow(ref.watch(simplifyDebtsProvider)(balances.byMember));
}

/// Who changed what, newest first.
@Riverpod(retry: noRetry)
Stream<List<HistoryEntry>> groupHistory(Ref ref, String groupId) =>
    ref.watch(watchGroupHistoryProvider)(groupId).map(_orThrow);

/// A fresh invite each time it's watched anew (the sheet opens).
@Riverpod(retry: noRetry)
Future<GroupInvite> invite(Ref ref, String groupId, {String? memberId}) async =>
    _orThrow(
      await ref.watch(createInviteProvider)(groupId, memberId: memberId),
    );

/// What an invite link leads to.
@Riverpod(retry: noRetry)
Future<InvitePreview> invitePreview(Ref ref, String link) async =>
    _orThrow(await ref.watch(previewInviteProvider)(link));
